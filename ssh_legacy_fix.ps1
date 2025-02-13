param (
    [string]$PublicKey
)

$sshConfig = @"
# This is the sshd server system-wide configuration file.  See
# sshd_config(5) for more information.

# The strategy used for options in the default sshd_config shipped with
# OpenSSH is to specify options with their default value where
# possible, but leave them commented.  Uncommented options override the
# default value.

#Port 22
#AddressFamily any
#ListenAddress 0.0.0.0
#ListenAddress ::

#HostKey __PROGRAMDATA__/ssh/ssh_host_rsa_key
#HostKey __PROGRAMDATA__/ssh/ssh_host_dsa_key
#HostKey __PROGRAMDATA__/ssh/ssh_host_ecdsa_key
#HostKey __PROGRAMDATA__/ssh/ssh_host_ed25519_key

# Ciphers and keying
#RekeyLimit default none

# Logging
#SyslogFacility AUTH
#LogLevel INFO

# Authentication:

#LoginGraceTime 2m
#PermitRootLogin prohibit-password
#StrictModes yes
#MaxAuthTries 6
#MaxSessions 10

#PubkeyAuthentication yes

# The default is to check both .ssh/authorized_keys and .ssh/authorized_keys2
# but this is overridden so installations will only check .ssh/authorized_keys
#AuthorizedKeysFile	.ssh/authorized_keys

#AuthorizedPrincipalsFile none

# For this to work you will also need host keys in %programData%/ssh/ssh_known_hosts
#HostbasedAuthentication no
# Change to yes if you don't trust ~/.ssh/known_hosts for
# HostbasedAuthentication
#IgnoreUserKnownHosts no
# Don't read the user's ~/.rhosts and ~/.shosts files
#IgnoreRhosts yes

# To disable tunneled clear text passwords, change to no here!
#PasswordAuthentication yes
#PermitEmptyPasswords no

#AllowAgentForwarding yes
#AllowTcpForwarding yes
#GatewayPorts no
#PermitTTY yes
#PrintMotd yes
#PrintLastLog yes
#TCPKeepAlive yes
#UseLogin no
#PermitUserEnvironment no
#ClientAliveInterval 0
#ClientAliveCountMax 3
#UseDNS no
#PidFile /var/run/sshd.pid
#MaxStartups 10:30:100
#PermitTunnel no
#ChrootDirectory none
#VersionAddendum none

# no default banner path
#Banner none

# override default of no subsystems
Subsystem	sftp	sftp-server.exe

# Example of overriding settings on a per-user basis
#Match User anoncvs
#	AllowTcpForwarding no
#	PermitTTY no
#	ForceCommand cvs server


PubkeyAuthentication yes
PasswordAuthentication no

Match Group administrators
       AuthorizedKeysFile __PROGRAMDATA__/ssh/administrators_authorized_keys

"@


function UTF8NoBom($filter) {
 $Utf8NoBomEncoding = New-Object System.Text.UTF8Encoding($False)
 foreach($i in ls -Recurse -Filter $filter) {
 $MyFile = Get-Content $i.fullname 
 [System.IO.File]::WriteAllLines($i.fullname, $MyFile, $Utf8NoBomEncoding)
 }
}

function SSH-Fix {
    ## Configure the OpenSSH server to use public key authentication
    Set-Content -Path "C:\ProgramData\ssh\sshd_config" -Value $sshConfig
    New-Item -Type File "C:\ProgramData\ssh\" -Name "administrators_authorized_keys"

    ## Add the provided public key to the server's authorized keys file
    $authorizedKeysPath = "C:\ProgramData\ssh\administrators_authorized_keys"
    if (Test-Path $authorizedKeysPath) {
        Add-Content -Path $authorizedKeysPath -Value $PublicKey
    } else {
        New-Item -ItemType Directory -path "C:\ProgramData\ssh\"
        New-Item -ItemType File -Path $authorizedKeysPath
        Add-Content -Path $authorizedKeysPath -Value $PublicKey
    }


    Set-Location “$ENV:ProgramData\ssh”
    UTF8NoBom(“*authorized_keys*”)

    $ak = “$ENV:ProgramData\ssh\administrators_authorized_keys”
    $acl = Get-Acl $ak
    $acl.SetAccessRuleProtection($true, $false)
    $administratorsRule = New-Object system.security.accesscontrol.filesystemaccessrule(“Administrators”,”FullControl”,”Allow”)
    $systemRule = New-Object system.security.accesscontrol.filesystemaccessrule(“SYSTEM”,”FullControl”,”Allow”)
    $acl.SetAccessRule($administratorsRule)
    $acl.SetAccessRule($systemRule)
    $acl | Set-Acl

}

SSH-Fix
Restart-Service sshd
