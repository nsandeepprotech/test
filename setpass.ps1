$Password = "kumar"
$UserAccount = Get-LocalUser -Name "runneradmin"
$UserAccount | Set-LocalUser -Password $Password
