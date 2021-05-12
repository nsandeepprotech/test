# Copyright: (c) 2018, Jordan Borean (@jborean93) <jborean93@gmail.com>
# MIT License (see LICENSE or https://opensource.org/licenses/MIT)

Function New-CygwinSetup {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "")]
    param (
        [Parameter(Mandatory=$true)][String]$Path,
        [Parameter(Mandatory=$true)][String]$SetupExe,
        [Parameter(Mandatory=$true)][String[]]$AnsibleVersions
    )

    $bash_exe = Join-Path -Path $Path -ChildPath "bin/bash.exe"
    # list of packages that are required to be present so we can install
    # Ansible and its dependencies
    $packages = "_autorebase,alternatives,base-cygwin,base-files,bash,binutils,bzip2,ca-certificates,coreutils,csih,curl,cygrunsrv,cygutils,cygwin-devel,dash,desktop-file-utils,diffutils,editrights,file,findutils,gamin,gawk,gcc-core,getent,grep,groff,gsettings-desktop-schemas,gzip,hostname,info,ipc-utils,less,libargp,libatomic1,libattr1,libblkid1,libbz2_1,libcom_err2,libcrypt0,libcurl4,libdb5.3,libedit0,libexpat1,libfam0,libffi-devel,libffi6,libgc2,libgcc1,libgcrypt20,libgdbm4,libglib2.0_0,libgmp10,libgomp1,libgpg-error0,libgssapi_krb5_2,libguile2.0_22,libiconv,libiconv2,libidn2_0,libintl8,libisl15,libk5crypto3,libkrb5_3,libkrb5support0,libltdl7,liblzma5,libmetalink3,libmpc3,libmpfr6,libncursesw10,libnghttp2_14,libopenldap2_4_2,libopenssl100,libp11-kit0,libpcre1,libpipeline1,libpopt-common,libpopt0,libpsl5,libquadmath0,libreadline7,libsasl2_3,libsigsegv2,libsmartcols1,libsodium-common,libsodium23,libsodium-devel,libsqlite3_0,libssh2_1,libstdc++6,libtasn1_6,libunistring2,libuuid-devel,libuuid1,libxml2,libxslt,libyaml0_2,login,make,man-db,mintty,ncurses,openssh,openssl,openssl-devel,p11-kit,p11-kit-trust,pkg-config,publicsuffix-list-dafsa,python,python-crypto,python2,python2-appdirs,python2-asn1crypto,python2-backports.ssl_match_hostname,python2-cffi,python2-chardet,python2-cryptography,python2-devel,python2-enum34,python2-idna,python2-ipaddress,python2-jinja2,python2-lockfile,python2-lxml,python2-markupsafe,python2-openssl,python2-packaging,python2-pip,python2-ply,python2-pycparser,python2-pyparsing,python2-requests,python2-setuptools,python2-six,python2-urllib3,python2-wheel,python2-yaml,rebase,run,sed,shared-mime-info,tar,terminfo,tzcode,tzdata,util-linux,vim-minimal,w32api-headers,w32api-runtime,which,windows-default-manifest,xz,zlib0"

    Write-Verbose -Message "Installing the required Cygwin packages to $Path"
    $arguments = @(
        "--quiet-mode",
        "--no-desktop",
        "--no-shortcuts",
        "--site", "http://cygwin.mirror.constant.com",
        "--root", $Path,
        "--packages", $packages
    )
    $rc = Invoke-Executable -Executable $SetupExe -Arguments $arguments
    if ($rc -ne 0) {
        throw "Failed to setup Cygwin with the required packages, rc: $rc"
    }

    Write-Verbose -Message "Upgrading pip and setuptools to the latest version"
    $rc = Invoke-BashCygwin -Executable $bash_exe -Arguments "pip2 install -U pip setuptools"
    if ($rc -ne 0) {
        Write-Warning -Message "Failed to update pip and setuptools to the latest version, rc: $rc"
    }

    # pynacl takes a while to install, we set SODIUM_INSTALL to make sure we
    # don't recompile libsodium during the install
    Write-Verbose -Message "Installing the required Python modules for Ansible/WinRM"
    $rc = Invoke-BashCygwin -Executable $bash_exe -Arguments "SODIUM_INSTALL=system pip2 install ansible pywinrm[credssp] virtualenv"
    if ($rc -ne 0) {
        throw "Failed to install the required Python packages in Cygwin for PSTestWinibleZ, rc: $rc"
    }

    Write-Verbose -Message "Removing Ansible from the base Python packages"
    $rc = Invoke-BashCygwin -Executable $bash_exe -Arguments "pip2 uninstall ansible -y"
    if ($rc -ne 0) {
        throw "Failed to remove Ansible from the base Python packages in Cygwin, rc: $rc"
    }

    $venvs = New-Object -TypeName System.Collections.ArrayList
    foreach ($version in $AnsibleVersions) {
        Write-Verbose -Message "Setting up virtualenv in Cygwin for Ansible $version"
        $venv_name = "PSTestWinibleZ-Ansible-$version"
        $rc = Invoke-BashCygwin -Executable $bash_exe -Arguments "virtualenv $venv_name --system-site-packages"
        if ($rc -ne 0) {
            throw "Failed to create virtualenv in Cygwin at $venv_name, rc: $rc"
        }

        Write-Verbose -Message "Install Ansible $version into the venv $venv_name"
        $rc = Invoke-BashCygwin -Executable $bash_exe -Arguments "$venv_name/bin/pip install ansible==$version ansible-lint"
        if ($rc -ne 0) {
            throw "Failed to install Ansible $version in the virtualenv $venv_name, rc: $rc"
        }

        # verify we can run the newly installed Ansible in the venv
        Invoke-BashCygwin -Executable $bash_exe -Arguments "$venv_name/bin/ansible --version" > $null

        $venvs.Add($venv_name) > $null
    }

    return ,$venvs
}
