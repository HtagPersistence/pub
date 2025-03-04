# Fonction pour convertir le CSV en YAML
function Convert-CsvToYaml {
    param (
        [string]$csvFilePath,
        [string]$yamlFilePath
    )

    # Lecture du fichier CSV
    $csvData = Import-Csv -Path $csvFilePath

    # Création d'une structure de données pour l'inventaire AWX
    $inventory = @{
        all = @{
            hosts = @()
            children = @{}
        }
    }

    # Parcours des lignes du CSV
    foreach ($row in $csvData) {
        $vmName = $row.VM
        $ip = $row.IPv4
        $folder = $row.Folder
        $os = $row.OS

        # Ajouter des informations supplémentaires sur chaque hôte
        $hostData = @{
            ip_adm = $ip
            os_version = $os
        }

        # Ajouter l'hôte à la liste des hôtes dans le groupe
        if (-not ($inventory['all']['children'].ContainsKey($folder))) {
            $inventory['all']['children'][$folder] = @{
                hosts = @{}
            }
        }

        $inventory['all']['children'][$folder].hosts[$vmName] = $hostData
        $inventory['all'].hosts += $vmName
    }

    # Convertir en YAML
    $yamlContent = ConvertTo-Yaml $inventory

    # Sauvegarder le fichier YAML
    Set-Content -Path $yamlFilePath -Value $yamlContent

    Write-Host "Le fichier YAML a été créé avec succès : $yamlFilePath"
}

# Fonction pour convertir un objet en YAML
function ConvertTo-Yaml {
    param (
        [Parameter(Mandatory=$true)]
        $Object
    )

    $yaml = ""

    foreach ($key in $Object.Keys) {
        $value = $Object[$key]
        
        if ($value -is [hashtable]) {
            $yaml += "${key}:`n"
            $yaml += ConvertTo-Yaml -Object $value
        } elseif ($value -is [array]) {
            $yaml += "${key}:`n"
            foreach ($item in $value) {
                $yaml += "  - $item`n"
            }
        } else {
            $yaml += "${key}: $value`n"
        }
    }

    return $yaml
}


# Spécifier les chemins du fichier CSV et du fichier YAML de sortie
$csvFilePath = ".\VM_listv2.csv"
$yamlFilePath = ".\VM_list.yml"

# Exécuter la fonction de conversion
Convert-CsvToYaml -csvFilePath $csvFilePath -yamlFilePath $yamlFilePath
