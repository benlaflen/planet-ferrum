# Ferrum: The Artifical Planet
Ferrum is the mysterious remnant of some long-gone civilization. It is unclear who created it or for what purpose, but it is now a valuable source for alien tech and rare earth metals... if you are skilled enough to extract them!

## Progression
Ferrum requires Vulcanus and Fulgora to be visited beforehand, and as such is designed to lie between the initial 3 vanilla planets and Aquilo. Like Aquilo, it is expected to import some buildings to start out. Nevertheless, you cannot be stranded on Ferrum, so there is no harm in starting it as early as possible. Completing Ferrum before Gleba will offer a recipe to potentially make Gleba easier.

## Experimental Mod
Planet Ferrum is a highly experimental mod, by which I mean it breaks the normal limits and expectations of the game in many aspects of its design. While the mod is fully compatible with vanilla and should work with most mods, and is **stable**, most things to do with Ferrum are very wacky indeed.

## Experiment 1: Atmosphere
![Remote control](https://i.imgur.com/548vohu.gif)
Ferrum's atmosphere is extremely ionized, due to it being primarily composed of the gaseous chemical and electrical seepage from within. This imposes three restrictions:

- It is impossible for the player to land on Ferrum. It can only be access via the remote view. This is a blessing and a curse. While handcrafting isn't possible,it is also impossible to be stranded on Ferrum; leave it alone to produce for a while and check back in on your next long spaceflight!
- The heavily ionized dust means that items exposed to the atmosphere would be quickly damaged. Thus, belts cannot be built on Ferrum until a particular technology is researched.
- For mechanical reasons related to the remote view and preventing hardlocks, at this time cargo landing pads cannot be built on Ferrum either. This may be changed in the future if it makes interplanetary logistics too hard. Recursive blueprints should allow construction robots to automatically deconstruct drop pads.

## Experiment 2: Technology
![Remote control](https://i.imgur.com/Tr7eXK4.jpeg)
![Remote control](https://i.imgur.com/wnF75Xl.jpeg)
Researching on Ferrum is a collaboration between the Engineer and the mysterious entity on the surface helping manage their communications. Over time, they will present you with choices between several new recipes. At each juncture, only one choice can be picked, and the tech tree will dynamically reconfigure triggers for the other recipes farther down the production chain based on what new items are craftable using the one you just unlocked, allowing you to unlock the full set in 12 different possible orders. **It is highly recommended to follow the production chain locally and only import buildings (or seed U-235 for kovarex...)**

## Experiment 3: Infuser
![Remote control](https://i.imgur.com/LCqIUqo.gif)
The infuser is a 1x1 hybrid chemical plant and belt that rapidly reacts liquids with items. Across its four sides it boasts a pipe in, a pipe out, a belt in, and a belt out, and will automatically bind to be eligible for any recipe (from any mod) that takes in one item and fluid and outputs a different item and fluid (this is far less common than it might seem to be fair, there are 2 such recipes in vanilla, up to 5 in K2SO). Thus, the infuser can be inlined into any belt to convert items flowing across via a fluid reaction.

## Experiment 4: Fabricator
![Remote control](https://i.imgur.com/hpphfmo.gif)
The fabricator is a hybrid roboport and assembler. Robots that are not currently assigned to tasks will prioritize docking in fabricators (unless other roboports are given robot requests), temporarily integrating into the building to provide their own specialized benefits to its production. The fabricator can accept up to 3 stacks of 10 robots each (filterable and integrated into the circuit network) to gain the following benefits:

- +0.5% quality per construction bot
- +5% speed per logistics bot
- +1.5% productivity per overclocking logistics bot or any modded bot

Thus, each fabricator can be dynamically reconfigured to boast up to 15% quality, 150% speed, or 45% productivity -- if you have enough spare bots!

## Experiment 5: Overclocking Robots
![Remote control](https://i.imgur.com/HTw9i87.gif)
An overclocking logistics robot functions like a normal logistics robot, but its powerful internal magnet is spun up each time it docks, leading to an EM pulse upon exiting the roboport that temporarily boosts the effectiveness of all beacons within the roboport's logistics range by +25% for 5s (refreshed if another pulse occurs while overclocked). How to keep the bots cycling in and out of the port is your problem!

## Raw Ingredients
![Remote control](https://i.imgur.com/QcAwqRm.gif)
As an artificial planet, most resources available are in the form of manufactured but discarded goods. Within the bowels of the crust run massive transport tubes that carry goods from one sector to another. Some of these have burst over time, leaving massive piles of iron gear wheels and flying robot frames scattered around the surface. Pure lubricant also seeps up in places where its arteries have burst. These 3 resources will need to be stretched to their absolute limits to get the planet self-sustaining (or just to craft basic plastic or copper...). Recycling plays an important role on Ferrum, although less so than Fulgora.

## Rare Earth Magnets
![Remote control](https://i.imgur.com/4Xohybb.gif)
The primary production chain on Ferrum revolves around producing rare earth magnets, based on the real-life steps rich clay goes through to make the magnets in all major computational technology. These magnets are used to craft the planet's Robotics Science pack, overclocking bots, and certain lategame vanilla recipes. The chain also integrates with the Linox and Moshine mods, as they touch on rare earth metal production as well, to add bridging recipes.

## Caveats
Ferrum has been tested with most of the required and optional planets in All The Planets Lite for loading compatibility, and has furthermore specifically been analyzed in relation to Linox, Moshine, and K2SO. It is designed to integrate safely with as many mods as possible, but this has of course not been tested on most mods. It also bears mentioning that all three experimental products (fabricators, infusers, and overclock bots) will require somewhat more UPS than their closest vanilla counterparts. While I have endeavored to keep UPS fairly low so that the average player need not think about it, these are probably going to perform fairly badly at megabase scale. Then again, robots are already bad at megabase scale, so that may be expected. Out of the three, overclock bots should be only slightly less performant than logistics bots, a fabricator should essentially have the UPS of a roboport + an assembler, and the infuser requires a small once-per-tick handler to do its custom belt logic that ought to make it the least performant at large scale.
