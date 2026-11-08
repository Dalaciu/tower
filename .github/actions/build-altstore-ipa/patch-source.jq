($perms[0] // {}) as $p
| .apps[0].size = ($size|tonumber)
| .apps[0].versionDate = $date
| .apps[0].minOSVersion = $min
| .apps[0].sha256 = $sha
| .apps[0].downloadURL = $url
| (if ($p|length) > 0 then .apps[0].appPermissions = $p else . end)
| .apps[0].versions = (
    [{
      version: $ver,
      date: $date,
      localizedDescription: ("Release " + $tag + "."),
      downloadURL: $url,
      size: ($size|tonumber),
      minOSVersion: $min,
      sha256: $sha
    } + (if ($p|length) > 0 then {appPermissions: $p} else {} end)]
    + ((.apps[0].versions // []) | map(select(.version != $ver)))
    | .[0:10]
  )
