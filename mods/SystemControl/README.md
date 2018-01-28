# System Control

The mod for the Avorion game (http://store.steampowered.com/app/445220/Avorion/), allows player to create 
the templates (sets) of upgrades for ship systems and quickly switch its from one to another.

For sure you had to open the menu of upgrades many times and rearrange the same system upgrades, 
especially for me it is relevant in the later stages of the game, when the ship has more than 10 installed 
systems. I switch them again and again, not because I got new ones, but because I want to get the most out of 
the ship, because I want to be able to shoot from 30-40 guns in combat, because I want to jump by 50 sectors, 
because I want to dismantle as quickly as possible, because I want to see more signatures on the map, 
carry more cargo, fly with maximum acceleration and so on. I again and again opened the management of systems 
and rearranged the same improvements, again and again, and this was the reason for creating this modification.

In addition, if you play in the alliance and fly on the ship of the alliance, then there is one more thin, 
it seems to me a flaw, in the fact that when installing and removing systems all the players of the alliance 
have info that I added new upgrades to the inventory of the alliance, or deleted cool rare upgrades and these 
messages filling the entire right side of the screen, 2-3 players are playing and you do not know when to be 
happy that someone added a new upgrade because the right side of the screen is constantly clogged with messages 
about systems replacing and you just start ignore them. So I tried to fix this flaw by adding the ability 
to use the player's inventory when installing or removing improvements. With the help of specially selected 
checkbox you can handle it or SystemControl use the inventory of the ship fraction or the player's inventory 
even if the ship belongs to the alliance.

## DOWNLOAD

## Installation

1. Download the mod ShipScriptLoader by Dirtyredz and follow its installation instructions. 
http://www.avorion.net/forum/index.php/topic,3918.0.html
This is required to load this modification. If you are already using it you may skip this step.

2. Copy the directory mods contained in the SystemControl.zip file directly into the Steam installation 
directory folder for Avorion.

3. Open the file Avorion/mods/ShipScriptLoader/config/ShipScriptLoader.lua
Before the last line containing return Config add this code:
	Config.Add("mods/SystemControl/scripts/entity/systemcontrol.lua")

## How to use

If you installed everything correctly, you should see a system upgrade icon at top-right of the screen.

Install desired upgrades through the standard interface and press an upgrade icon, its will open 
the SystemControl window.

The topmost line (1) shows the current systems installed on the ship, the other lines show your templates
saved earlier. [Update](2) button will replace the template by the current list of upgrades.
The [Apply](3) button calls the SystemControl to find and install the upgrades according the tamplate. 
Search will be made in the player's inventory or ship's faction, depending on the status of 
the checkbox [Use player inventory](4).
You can use hot keys to apply the required template Alt + #number of template.
Alt + 0 will remove all installed system upgrades.
Templates do not store upgrades, they just remember which systems should be installed, and try to search 
for these in the inventory.

## Known issues

* Upgrades do not drops out of the ship during a crash.
In the event of partial destruction or change in the ship size the upgrades are sent to the player's inventory.
But if the ship is lost from the collision, or lost its HP without losing the processing power, the installed 
improvements will be lost.

* Upgrades that are installed by SystemControl are not displayed in the standard [system upgrades] menu. 
The developer did not give the opportunity to correctly install ship system upgrades(or I can't find that way, 
help me if I wrong), in form an API for working with inventory or somethig like it, or will allow to modify 
the standard interface. 
If I have one then it will be possible to improve the level of integration with the base UI.

## Future improvements

* Add sounds to hotkeys
* Save the current system set into the template by pressing Shift + Alt + #number

## Credits

* Dirtyredz for the ShipScriptLoader.
* Multirez (it's my forum niñkname) for everything else :)