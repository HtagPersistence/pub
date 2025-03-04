import csv
import yaml

# Fichier CSV en entrée
input_file = "data.csv"

# Dictionnaire pour stocker les hôtes par groupe
ansible_inventory = {"all": {"hosts": {}, "children": {}}}

# Lire le fichier CSV et générer le format d'inventaire Ansible
with open(input_file, mode="r") as file:
    csv_reader = csv.DictReader(file)
    for row in csv_reader:
        vm = row["VM"]
        ipv4 = row["IPv4"]
        folder = row["Folder"]
        os = row["OS"]

        # Ajout de chaque hôte au groupe 'all' avec ses variables
        ansible_inventory["all"]["hosts"][vm] = {
            "ipv4": ipv4,
            "os": os,
            "folder": folder,
        }

# Sauvegarder l'inventaire au format YAML
output_file = "ansible_inventory.yml"
with open(output_file, "w") as yaml_file:
    yaml.dump(ansible_inventory, yaml_file, default_flow_style=False)

print(f"Fichier d'inventaire Ansible généré : {output_file}")
