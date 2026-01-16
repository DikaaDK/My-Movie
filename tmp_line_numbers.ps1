$counter = 0
Get-Content 'lib/services/anime_api.dart' | ForEach-Object {
  $counter++
  if ($counter -le 220) {
    Write-Output ("{0}: {1}" -f $counter, $_)
  }
}
