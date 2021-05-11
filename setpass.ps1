#Set-ADAccountPassword -Identity runneradmin -Reset -NewPassword (ConvertTo-SecureString -AsPlainText "sandeep" -Force)
Set-ADAccountPassword -Identity runneradmin -NewPassword sandeep -Reset
