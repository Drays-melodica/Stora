# STORA — Gestionnaire de stock (Windows)

**STORA** est un logiciel de gestion de stock professionnel pour Windows, développé en **Flutter**.  
Interface **style BIOS/DOS** : fond bleu nuit, texte blanc, navigation **clavier uniquement**, lancement en **plein écran**.

## Fonctionnalités

| Module | Description |
|--------|-------------|
| **Clients** | Fiches clients pour commandes de vente |
| **Entrepôts** | Multi-entrepôts + stock par emplacement |
| **Commandes achat** | Bons de commande + réception stock |
| **Commandes vente** | Commandes clients + livraison / sortie |
| **Transferts** | Transfert de stock entre entrepôts |
| **Lots / péremption** | Traçabilité lots et alertes < 30 jours |
| **Retours** | Retours client (+) et fournisseur (-) |
| **Sauvegarde** | Copie de la base vers dossier, USB ou Google Drive (+ restauration admin) |
| **Société** | Nom, coordonnées et logo sur les en-têtes imprimés (admin) |
| **Authentification** | Création admin au 1er lancement, connexion, déconnexion |
| **Agents** | L'admin peut créer/désactiver des agents de stock |
| **Traçabilité** | Chaque mouvement enregistre le nom de l'agent connecté |
| **Produits** | Création, modification, suppression, recherche, étiquettes |
| **Catégories** | Organisation des produits |
| **Fournisseurs** | Carnet fournisseurs |
| **Entrées de stock** | Réceptions avec référence et notes |
| **Sorties de stock** | Consommations avec contrôle du stock |
| **Inventaire** | Ajustement des quantités après comptage |
| **Journal** | Historique complet des mouvements |
| **Rapports** | Impression PDF (stock complet, alertes, journal) |
| **Paramètres** | Infos système et emplacement de la base |

## Prérequis

1. [Flutter SDK](https://docs.flutter.dev/get-started/install/windows) (3.16+) — sur ce PC : `D:\flutter\bin`
2. Visual Studio 2022+ avec charge de travail **« Développement Desktop en C++ »**
3. Windows 10/11

> **Note :** Si `flutter` n'est pas reconnu, ajoutez `D:\flutter\bin` au PATH ou préfixez les commandes :
> `$env:Path = "D:\flutter\bin;" + $env:Path`

Vérification :

```powershell
flutter doctor
```

## Installation

Ouvrez PowerShell dans le dossier du projet :

```powershell
cd "C:\Users\Drays Melodica\Desktop\Stora"

# Génère les fichiers plateforme Windows (si absents)
flutter create . --project-name stora --platforms windows

flutter pub get
flutter run -d windows
```

## Compilation (exécutable)

```powershell
flutter build windows --release
```

L'exécutable se trouve dans :  
`build\windows\x64\runner\Release\stora.exe`

## Raccourcis clavier

| Touche | Action |
|--------|--------|
| `↑` `↓` | Naviguer dans les listes et menus |
| `Entrée` | Valider / Ouvrir |
| `Échap` | Retour / Annuler |
| `F1` | Produits (menu) / À propos (paramètres) |
| `F2` | Entrée de stock (menu) / Nouveau (listes) |
| `F3` | Sortie de stock (menu) / Supprimer |
| `F4` | Rapports (menu) / Imprimer |
| `F5` | Rechercher (produits) |
| `F10` | Valider un formulaire |
| `1`–`9` | Sélection rapide dans les menus |

## Base de données

- Moteur : **SQLite** (fichier local)
- Emplacement : dossier de données de l'application (`path_provider`)
- **Premier démarrage** (aucune base) : choix entre nouvelle installation,
  restauration depuis un fichier `.db`, ou restauration depuis **Google Drive en ligne**
- Menu **SAUVEGARDE / RESTAURATION** : dossier, USB, ou upload cloud Google Drive (API)

### Google Drive (API en ligne)

1. Google Cloud Console → activer **Google Drive API**
2. Créer un client OAuth **Application de bureau** (Client ID + Secret)
3. Dans STORA → **CONFIGURER GOOGLE DRIVE (OAuth)**
4. À la première sauvegarde, autoriser l'accès dans le navigateur
5. Les fichiers vont dans le dossier Drive `STORA_Backups`

## Impression

Les rapports sont générés en **PDF** via le dialogue d'impression Windows (imprimante ou fichier PDF).

## Design

- Fond : bleu nuit `#000033`
- Texte : blanc
- Police : Courier New (style terminal)
- Plein écran au démarrage (`window_manager`)

## Licence

STORA est un **logiciel libre et ouvert** — aucune clé d'activation n'est requise.

## Structure du projet

```
lib/
  main.dart              # Point d'entrée, plein écran
  app.dart               # Application Material
  database/              # SQLite
  models/                # Produits, mouvements, etc.
  screens/               # Écrans DOS
  services/              # Stock, impression, auth
  theme/                 # Couleurs BIOS
  widgets/               # Composants clavier (menu, table, formulaire)
```
