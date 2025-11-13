$virtioPath = "E:\"
$drivers = Get-ChildItem "$virtioPath\*inf" -Recurse
foreach ($driver in $drivers) {
    pnputil.exe -i -a $driver.FullName
}
