(() => {
  "use strict";

  const STOP_WORDS = new Set([
    "a","an","and","are","as","at","be","build","can","could","do","for","from","get","he","her","him","how","i","if","in","into","is","it","make","me","my","of","on","or","our","she","something","that","the","their","them","then","they","thing","this","to","us","use","want","we","when","with","would","you","your"
  ]);

  const INTENTS = [
    { id:"input", terms:["input","keyboard","keyboard key","button press","press","controller","gamepad","controls","click"], suggestions:[
      [["Input Map"],"Detect a player input action such as move, jump, interact, or attack."] ] },
    { id:"mouse_input", terms:["mouse","mouse click","mouse button","cursor","wheel","hover","click"], suggestions:[
      [["Mouse"],"Detect mouse buttons, movement, wheel input, or hovering."] ] },
    { id:"move", terms:["move","movement","walk","run","sprint","strafe","drive","fly","travel","go","locomotion","speed","velocity","movement control"], suggestions:[
      [["Motion 2D","Motion"],"Move or rotate the controlled object."],
      [["Character 2D Physics","Character Physics"],"Apply character movement and physics each frame."],
      [["Input Map"],"Detect the player's movement controls."] ] },
    { id:"character", terms:["character","player","enemy","npc","non player character","monster","creature","hero","avatar","opponent","bad guy","boss","character controller","characterbody","character body"], suggestions:[
      [["Character Physics"],"Apply 3D character movement and physics each frame."],
      [["Character 2D Physics"],"Apply 2D character movement and physics each frame."],
      [["Character Jump"],"Add jumping behavior to a 3D character."],
      [["Character Jump 2D"],"Add jumping behavior to a 2D character."] ] },
    { id:"jump", terms:["jump","hop","leap","double jump","platformer"], suggestions:[
      [["Character Jump 2D","Character Jump"],"Apply a jump to a character."],
      [["Physics 2D","Physics"],"Check whether the character is on the floor before jumping."],
      [["Input Map"],"Detect the jump action."] ] },
    { id:"collision", terms:["collision","collide","touch","hit","overlap","contact","bump","trigger","trigger area","trigger zone","enter area","walk into","run into"], suggestions:[
      [["Collision 2D","Collision"],"Detect when objects touch or enter a collision area."],
      [["Physics 2D","Physics"],"Check floor, wall, or ceiling contact for a character."] ] },
    { id:"near", terms:["near","nearby","close","close to","distance","range","within range","approach","radius","proximity","get close","comes close"], suggestions:[
      [["Proximity 2D","Proximity"],"Detect when a target is within a chosen distance or angle."],
      [["Raycast 2D","Raycast"],"Check whether something is directly detectable along a ray."] ] },
    { id:"see", terms:["see","sight","line of sight","vision","detect","detect player","sense","notice","spot","find player","visible to enemy","can see","look for"], suggestions:[
      [["Raycast 2D","Raycast"],"Test line of sight or whether an object is in front of something."],
      [["Proximity 2D","Proximity"],"Limit detection to a nearby distance or viewing angle."] ] },
    { id:"chase", terms:["chase","follow","follow player","pursue","hunt","track player","come after","go after","run after","enemy follow"], suggestions:[
      [["Proximity 2D","Proximity"],"Decide when the target is close enough to react to."],
      [["Move Towards"],"Move an enemy toward a target or pathfind toward it."],
      [["Rotate Towards"],"Turn an enemy so it faces the target."],
      [["Raycast 2D","Raycast"],"Optionally require clear line of sight before chasing."] ] },
    { id:"patrol", terms:["patrol","waypoint","route","path","guard route","walk between"], suggestions:[
      [["Waypoint Path"],"Move through a sequence of waypoints."],
      [["Move Towards"],"Move toward a current patrol target."],
      [["Delay"],"Pause at a waypoint before continuing."] ] },
    { id:"rotate", terms:["rotate","turn","face","aim","look at","point toward","track target"], suggestions:[
      [["Rotate Towards"],"Rotate an object so it faces a target."],
      [["Look At Input"],"Rotate from player look input."],
      [["Look At Movement"],"Face in the direction the object is moving."] ] },
    { id:"variable", terms:["variable","value","score","health","lives","ammo","counter","number","boolean","flag","state value"], suggestions:[
      [["Compare Variable","Variable"],"Check a stored value before allowing logic to continue."],
      [["Modify Variable"],"Increase, decrease, assign, or otherwise change a stored value."],
      [["Get Variable"],"Read a value from another source for later logic."] ] },
    { id:"inventory", terms:["inventory","array","list","collection","items","item list","has item","contains item","backpack","equipment","storage","remember collected"], suggestions:[
      [["Compare Variable","Variable"],"Check whether an Array contains an item or whether it is empty."],
      [["Modify Variable"],"Add, remove, clear, or edit items in an Array."],
      [["Get Variable"],"Read a stored inventory or Array value when needed elsewhere."] ] },
    { id:"pickup", terms:["pickup","pick up","collect","collecting","coin","gem","key","loot","grab","obtain","get item","collectible","powerup","power up","bonus item"], suggestions:[
      [["Collision 2D","Collision"],"Detect when the player reaches the collectible."],
      [["Modify Variable"],"Add the collected item or increase a score/count."],
      [["Edit Object"],"Remove or otherwise change the collected object."],
      [["Visibility"],"Hide a collected object if you do not want to remove it."] ] },
    { id:"door", terms:["door","locked","unlock","key door","gate","open door","close door","locked door","doorway"], suggestions:[
      [["Compare Variable","Variable"],"Check whether the required key or condition exists."],
      [["Animation"],"Play an opening or closing animation."],
      [["Property"],"Change a door property when it unlocks or opens."],
      [["Collision"],"Enable or disable collision on a 3D door or barrier."] ] },
    { id:"timer", terms:["timer","time","delay","wait","seconds","countdown","after a while","cooldown","interval","every few","every second","pause before"], suggestions:[
      [["Delay"],"Wait before firing logic, or repeat logic at an interval."] ] },
    { id:"random", terms:["random","chance","probability","sometimes","randomly","loot chance","random behavior"], suggestions:[
      [["Random"],"Activate logic based on a random chance."],
      [["Delay"],"Control how often a random check happens."] ] },
    { id:"message", terms:["signal","message","tell another","notify","communicate","broadcast","event message"], suggestions:[
      [["Signal"],"Send or receive a named signal between logic chains or nodes."] ] },
    { id:"interaction", terms:["interact","interaction","use","activate","press to use","press e","talk to","talk with","open chest","use object","activate switch","switch","lever"], suggestions:[
      [["Input Map"],"Detect the player's interact/use action."],
      [["Collision 2D","Collision"],"Detect when the player is close enough or touching the interactive object."],
      [["Signal"],"Tell another node or logic chain that the interaction happened."],
      [["Property"],"Change the target object's state or properties after interaction."] ] },
    { id:"combat", terms:["attack","combat","fight","hit enemy","damage","hurt","shoot","shooting","fire weapon","weapon","gun","sword","melee","bullet","projectile","kill enemy","enemy dies","die","death"], suggestions:[
      [["Input Map"],"Detect an attack, fire, or action input from the player."],
      [["Raycast 2D","Raycast"],"Detect a target for hitscan attacks, aiming, or line-of-sight hits."],
      [["Collision 2D","Collision"],"Detect projectile, melee, or contact hits."],
      [["Modify Variable"],"Change health, ammo, damage counters, or other combat values."],
      [["Object Pool"],"Spawn reusable bullets or projectiles efficiently."] ] },
    { id:"health", terms:["health","hp","hit points","life","lives","heart","hearts","damage","damaged","hurt","take damage","lose health","heal","healing","restore health","health bar","dead","death","die"], suggestions:[
      [["Modify Variable"],"Increase or decrease a health or lives variable."],
      [["Compare Variable","Variable"],"Check health thresholds such as zero, low health, or maximum health."],
      [["Progress Bar"],"Display health as a changing bar in the interface."],
      [["Text"],"Display health, lives, or other status values as text."] ] },
    { id:"object", terms:["object","thing","item","entity","actor","prop","node","scene object"], suggestions:[
      [["Property"],"Change a property on an object or node."],
      [["Set Transforms"],"Change an object's position, rotation, or scale."],
      [["Visibility"],"Show or hide an object."],
      [["Edit Object"],"Create, remove, or otherwise edit a scene object."] ] },
    { id:"state_logic", terms:["state","mode","phase","status","on off","enabled disabled","only once","one time","do once","every frame","always"], suggestions:[
      [["State"],"Change or manage which logic state is active."],
      [["Always"],"Run logic continuously while the brick is enabled."],
      [["Once"],"Allow an action or condition to happen only once when needed."] ] },
    { id:"animation", terms:["animation","animate","play animation","idle","walk animation","attack animation","sprite animation"], suggestions:[
      [["Animation"],"Play, stop, or control an AnimationPlayer animation."],
      [["Sprite Animation"],"Control AnimatedSprite2D animations."],
      [["Animation State"],"Change or control animation states."],
      [["Animation Tree"],"Read AnimationTree state or parameter conditions."] ] },
    { id:"audio", terms:["sound","audio","sfx","sound effect","noise","play sound","footstep"], suggestions:[
      [["2D Audio","3D Audio"],"Play a sound effect in the scene."],
      [["Music"],"Control longer music tracks separately from sound effects."] ] },
    { id:"music", terms:["music","song","track","background music","crossfade"], suggestions:[
      [["Music"],"Play, stop, pause, resume, select, or crossfade music tracks."] ] },
    { id:"camera", terms:["camera","follow camera","camera follow","camera follows player","zoom","third person","first person","view","screen view","switch camera"], suggestions:[
      [["Smooth Follow Camera","3rd Person Camera"],"Make a camera follow a target."],
      [["Camera Zoom"],"Change camera zoom or field of view."],
      [["Set Camera"],"Switch which camera is active."] ] },
    { id:"scene", terms:["scene","level","map","room","stage","change level","next level","restart level","load scene","menu scene","next scene","change scene"], suggestions:[
      [["Scene"],"Change, add, restart, or otherwise control scenes."],
      [["Game"],"Restart, pause, exit, or control the running game."] ] },
    { id:"spawn", terms:["spawn","create","create object","create enemy","instantiate","generate","make enemy","make object","appear","projectile","bullet","fire bullet","spawn point"], suggestions:[
      [["Object Pool"],"Spawn reusable objects efficiently, especially repeated enemies or projectiles."],
      [["Edit Object"],"Create or modify scene objects when the action occurs."] ] },
    { id:"remove", terms:["delete","destroy","remove","remove object","despawn","disappear","kill","kill object","erase","get rid of"], suggestions:[
      [["Edit Object"],"Remove or otherwise edit an object in the scene."],
      [["Visibility"],"Hide an object when it should disappear without deleting it."] ] },
    { id:"teleport", terms:["teleport","portal","respawn","respawn point","checkpoint","warp","spawn location","return to checkpoint","return to spawn"], suggestions:[
      [["Teleport 2D","Teleport"],"Instantly move an object to coordinates or a target node."],
      [["Save / Load"],"Store and restore progress or a saved position when appropriate."],
      [["Collision 2D","Collision"],"Detect reaching a portal or checkpoint area."] ] },
    { id:"save", terms:["save","load","save game","load game","checkpoint data","persistence","remember progress"], suggestions:[
      [["Save / Load"],"Save and restore node transforms and variables."],
      [["Modify Variable"],"Store values that should be included in saved game state."] ] },
    { id:"physics", terms:["physics","gravity","fall","falling","ground","floor","wall","ceiling","platform","slope","push","force","impulse","knockback","velocity","rigidbody","rigid body"], suggestions:[
      [["Gravity"],"Apply or control gravity behavior."],
      [["Force 2D","Force"],"Apply a continuing physical force."],
      [["Impulse 2D","Impulse"],"Apply a one-time physical impulse such as knockback."],
      [["Linear Velocity 2D","Linear Velocity"],"Set or change linear velocity directly."] ] },
    { id:"ui", terms:["ui","hud","interface","menu","label","text","health bar","health meter","progress bar","score display","score text","slider","popup","window","tab"], suggestions:[
      [["Text"],"Change text shown in the interface."],
      [["Progress Bar"],"Display a changing value such as health or progress."],
      [["Button"],"React to UI button interaction."],
      [["Popup"],"Show or control a popup interface element."],
      [["Visibility"],"Show or hide interface elements."] ] },
    { id:"health", terms:["health","hp","damage","hurt","take damage","heal","healing","dead","death","lives"], suggestions:[
      [["Modify Variable"],"Decrease health for damage, increase it for healing, or change lives."],
      [["Compare Variable","Variable"],"Check for conditions such as health reaching zero."],
      [["Progress Bar"],"Display health visually in the UI."],
      [["Object Flash"],"Give visual feedback when an object takes damage."],
      [["Hit Stop"],"Add impact feedback to a successful hit."] ] },
    { id:"score", terms:["score","points","high score","counter","coins count","kill count"], suggestions:[
      [["Modify Variable"],"Increase or decrease a score or counter."],
      [["Compare Variable","Variable"],"Check when a score reaches a goal."],
      [["Text"],"Display the current score in the UI."] ] },
    { id:"pause", terms:["pause","pause menu","resume","unpause"], suggestions:[
      [["Game"],"Pause or resume the game."],
      [["Visibility"],"Show or hide a pause-menu interface."],
      [["Input Map"],"Detect the pause action."] ] },
    { id:"visual", terms:["flash","shake","feedback","impact","screen shake","camera shake","rumble","vibrate","hit effect"], suggestions:[
      [["Screen Shake","Object Shake"],"Add shake feedback to impacts or dramatic events."],
      [["Screen Flash","Object Flash"],"Flash the screen or an object for feedback."],
      [["Rumble"],"Trigger controller vibration."],
      [["Hit Stop"],"Briefly slow or freeze time on an impact."] ] },
    { id:"visibility", terms:["show","hide","visible","invisible","toggle visibility","appear","disappear"], suggestions:[
      [["Visibility"],"Show, hide, or toggle a node's visibility."],
      [["Modulate"],"Change color or transparency for a 2D/UI node."] ] },
    { id:"property", terms:["property","change property","set property","color","scale","size","position value"], suggestions:[
      [["Property"],"Set supported properties on another node."],
      [["Set Transforms"],"Set position, rotation, or scale values."],
      [["Tween","Tween Animation"],"Change a property smoothly over time."] ] }
  ];

  // Curated beginner game-mechanic phrases. These are intentionally kept in
  // one data block so new classroom-language misses can be added without
  // scattering special cases through the ranking code. Phrase matches receive
  // a stronger boost than individual vocabulary words because the combination
  // carries more meaning (for example, "moving platform" is more specific than
  // either "moving" or "platform" by itself).
  const COMMON_MECHANICS = [
    { id:"moving_platform", phrases:["moving platform","platform moves","platform move","move platform","back and forth platform","platform back and forth","platform between points","platform between waypoints","elevator","lift platform","moving elevator"], suggestions:[
      [["Waypoint Path"],"Move the platform repeatedly through a sequence of points or along a Path3D curve."],
      [["Tween","Tween Animation"],"Smoothly animate a platform property or transform when a waypoint path is not needed."],
      [["Always"],"Keep continuous platform movement logic active when the behavior should run all the time."] ] },
    { id:"enemy_patrol", phrases:["enemy patrol","monster patrol","npc patrol","guard patrol","patrol between points","patrol between waypoints","walk between points","walk between waypoints","follow patrol route"], suggestions:[
      [["Waypoint Path"],"Move an enemy or NPC through a predefined patrol route."],
      [["Delay"],"Pause at patrol points before continuing."],
      [["Rotate Towards"],"Turn the patrolling character toward its next target when needed."] ] },
    { id:"rotating_platform", phrases:["rotating platform","spinning platform","platform rotates","platform spins","spin object","rotating object"], suggestions:[
      [["Set Transforms"],"Change rotation values on a platform or object."],
      [["Tween","Tween Animation"],"Animate rotation smoothly over time."],
      [["Always"],"Keep a continuously rotating object updating."] ] },
    { id:"falling_platform", phrases:["falling platform","platform falls","drop platform","platform drops","breakaway platform"], suggestions:[
      [["Collision"],"Detect when the player reaches or stands on the platform."],
      [["Delay"],"Wait briefly before the platform falls."],
      [["Set Transforms"],"Move the platform downward after it is triggered."] ] },
    { id:"disappearing_platform", phrases:["disappearing platform","platform disappears","vanishing platform","platform vanishes","temporary platform"], suggestions:[
      [["Collision"],"Detect when the player reaches the platform."],
      [["Delay"],"Control how long the platform remains before disappearing or returning."],
      [["Visibility"],"Show or hide the platform."],
      [["Property"],"Change a platform property such as collision state when it disappears."] ] },
    { id:"jump_pad", phrases:["jump pad","bounce pad","spring pad","launch pad","bounce player","launch player"], suggestions:[
      [["Collision"],"Detect when the player touches the pad."],
      [["Character Jump"],"Apply an upward jump-like impulse to a 3D character."],
      [["Physics"],"Use character physics information when the launch depends on floor or collision state."] ] },
    { id:"locked_door", phrases:["locked door","key opens door","open door with key","door needs key","unlock door","key door"], suggestions:[
      [["Compare Variable","Variable"],"Check whether the player has the required key or condition."],
      [["Animation"],"Play the door opening animation after it unlocks."],
      [["Property"],"Change the door's state or collision-related properties after unlocking."] ] },
    { id:"switch_door", phrases:["switch opens door","button opens door","lever opens door","pressure plate opens door","floor switch","pressure plate","door switch"], suggestions:[
      [["Collision"],"Detect a player or object activating a pressure plate or trigger."],
      [["Input Map"],"Detect an interact action for a button, switch, or lever."],
      [["Signal"],"Tell the door that the switch or plate was activated."],
      [["Animation"],"Play the door opening or closing animation."] ] },
    { id:"interact_prompt", phrases:["press e to interact","press button to interact","interact with object","use object","activate object","talk to npc","talk to character"], suggestions:[
      [["Input Map"],"Detect the player's interact/use action."],
      [["Proximity"],"Check that the player is close enough to interact."],
      [["Signal"],"Notify the target object that the interaction happened."] ] },
    { id:"pickup_item", phrases:["pick up item","pickup item","collect item","collect coin","collect gem","pick up key","pickup key","health pickup","ammo pickup","power up","powerup"], suggestions:[
      [["Collision"],"Detect when the player reaches the collectible."],
      [["Modify Variable"],"Record the item, health, ammo, score, or inventory change."],
      [["Visibility"],"Hide the collected object after pickup."],
      [["Edit Object"],"Remove or otherwise change the collected object when appropriate."] ] },
    { id:"unique_pickup", phrases:["only collect once","dont collect twice","don't collect twice","prevent duplicate item","no duplicate item","add item once","unique inventory item"], suggestions:[
      [["Compare Variable","Variable"],"Check that the Array does not already contain the item."],
      [["Modify Variable"],"Add the item only after the comparison succeeds."] ] },
    { id:"checkpoint", phrases:["checkpoint","save point","respawn point","return to checkpoint","go back to checkpoint","respawn at checkpoint"], suggestions:[
      [["Get Transforms"],"Read and remember a checkpoint position or transform."],
      [["Set Transforms"],"Move the player back to the saved checkpoint transform."],
      [["Modify Variable"],"Store checkpoint state or which checkpoint is active."],
      [["Collision"],"Detect when the player reaches a checkpoint."] ] },
    { id:"teleporter", phrases:["teleporter","teleport","portal","warp","warp point","move player instantly","teleport player"], suggestions:[
      [["Teleport"],"Instantly move the player or object to a destination node or coordinates."],
      [["Collision"],"Detect when the player enters a teleporter or portal."],
      [["Signal"],"Trigger teleport behavior on another object or logic chain when useful."] ] },
    { id:"next_level", phrases:["next level","change level","change scene","load level","go to next scene","restart level","restart scene","return to menu","main menu"], suggestions:[
      [["Scene"],"Change, reload, or manage the current scene for level and menu transitions."],
      [["Collision"],"Detect a level exit or goal trigger when the transition is world-based."],
      [["Input Map"],"Detect a button/action that starts the scene change."] ] },
    { id:"shoot_projectile", phrases:["shoot bullet","fire bullet","shoot projectile","fire projectile","shoot weapon","fire weapon","gun shoots","spawn bullet","spawn projectile"], suggestions:[
      [["Input Map"],"Detect the fire action when the player controls the weapon."],
      [["Object Pool"],"Spawn and reuse bullets or projectiles efficiently."],
      [["Collision"],"Detect projectile impacts."],
      [["Modify Variable"],"Track ammo, health, or damage values when needed."] ] },
    { id:"enemy_shoots", phrases:["enemy shoots player","enemy fires at player","turret shoots player","enemy projectile","enemy gun"], suggestions:[
      [["Proximity"],"Decide when the player is close enough for the enemy to attack."],
      [["Raycast"],"Optionally check line of sight before firing."],
      [["Rotate Towards"],"Aim the enemy toward the player."],
      [["Object Pool"],"Spawn reusable enemy projectiles efficiently."] ] },
    { id:"take_damage", phrases:["take damage","lose health","hurt player","damage player","damage enemy","enemy takes damage","player gets hurt"], suggestions:[
      [["Collision"],"Detect contact, projectile, or hazard hits."],
      [["Modify Variable"],"Decrease the target's health value."],
      [["Compare Variable","Variable"],"Check for zero health or other damage thresholds."] ] },
    { id:"health_bar", phrases:["health bar","hp bar","life bar","show health","display health"], suggestions:[
      [["Progress Bar"],"Display health as a changing bar in the UI."],
      [["Get Variable"],"Read the gameplay health value for display logic."],
      [["Modify Variable"],"Maintain the health value that the display represents."] ] },
    { id:"score_display", phrases:["score display","show score","display score","score text","points display","points on screen"], suggestions:[
      [["Text"],"Display the current score or points in the UI."],
      [["Get Variable"],"Read the gameplay score value for display logic."],
      [["Modify Variable"],"Increase, decrease, or assign the score value."] ] },
    { id:"countdown", phrases:["countdown","countdown timer","time limit","wait seconds","after a few seconds","every few seconds","repeat every","cooldown"], suggestions:[
      [["Delay"],"Wait for a duration or repeat logic at an interval."],
      [["Modify Variable"],"Store a visible countdown value when the game needs one."],
      [["Text"],"Display a countdown or remaining time in the UI."] ] },
    { id:"enemy_chase", phrases:["enemy chase player","enemy chases player","monster chase player","npc follows player","enemy follows player","bad guy follows player","enemy comes after player"], suggestions:[
      [["Proximity"],"Decide when the player is close enough for the enemy to react."],
      [["Move Towards"],"Move or pathfind the enemy toward the player."],
      [["Rotate Towards"],"Keep the enemy facing its target."],
      [["Raycast"],"Optionally require clear line of sight before chasing."] ] },
    { id:"camera_follow", phrases:["camera follows player","follow camera","camera follow","third person camera","3rd person camera","camera tracks player"], suggestions:[
      [["Smooth Follow Camera"],"Have the camera smoothly follow a target."],
      [["3rd Person Camera"],"Use a third-person camera setup around the player."],
      [["Set Camera"],"Choose or switch the active camera when needed."] ] },
    { id:"hazard", phrases:["spikes hurt player","lava hurts player","hazard damages player","damage zone","kill zone","death zone","instant death"], suggestions:[
      [["Collision"],"Detect when the player enters or touches the hazard."],
      [["Modify Variable"],"Reduce health or lives when the hazard is triggered."],
      [["Compare Variable","Variable"],"Check whether damage caused a death or fail condition."] ] },
    { id:"spawn_waves", phrases:["spawn enemies","enemy spawner","spawn enemy","enemy wave","wave of enemies","spawn every few seconds","respawn enemy"], suggestions:[
      [["Object Pool"],"Create and reuse enemies efficiently when many may be spawned."],
      [["Delay"],"Control spawn timing or intervals."],
      [["Random"],"Add random variation to spawn timing or choices when desired."] ] },
    { id:"win_condition", phrases:["win condition","player wins","beat level","complete level","finish level","all enemies defeated","collect all"], suggestions:[
      [["Compare Variable","Variable"],"Check whether the required score, count, state, or objective has been reached."],
      [["Scene"],"Move to a results screen, next level, or other scene after winning."],
      [["Signal"],"Notify other logic that the win condition has been met."] ] },
    { id:"game_over", phrases:["game over","lose condition","player loses","out of lives","zero health","player dies","player death"], suggestions:[
      [["Compare Variable","Variable"],"Check for zero health, zero lives, or another failure condition."],
      [["Scene"],"Reload the level or switch to a game-over scene."],
      [["Animation"],"Play a death or failure animation before the transition when needed."] ] }
  ];

  const RECIPE_BOOSTS = [
    { all:["inventory","door"], extra:[[["Compare Variable","Variable"],"Check the inventory for the required item before opening the door."],[["Animation"],"Play the door opening animation after the condition succeeds."]] },
    { any:["shoot","gun","weapon","fire"], extra:[[["Input Map"],"Detect the fire action."],[["Object Pool"],"Spawn reusable bullets or projectiles efficiently."],[["Raycast 2D","Raycast"],"Use a ray for hitscan weapons or aiming checks."]] },
    { any:["enemy","monster","npc","bad guy"], all:["chase"], extra:[[["Move Towards"],"Move or pathfind toward the player."],[["Rotate Towards"],"Keep the enemy facing its target."]] },
    { any:["collect","pickup","coin","gem","key"], extra:[[["Collision 2D","Collision"],"Detect the collection event."],[["Modify Variable"],"Record the item or update a score/count."]] }
    ,{ any:["enemy","monster","npc","boss","bad guy"], extra:[[["Character Physics"],"Use character physics for a moving 3D enemy or NPC."],[["Proximity 2D","Proximity"],"Detect when the player is near enough for the enemy to react."]] }
    ,{ any:["health","hp","heart","hearts"], extra:[[["Modify Variable"],"Store and change the character's health value."],[["Progress Bar"],"Show the current health value visually in the HUD."]] }
    ,{ any:["interact","activate","use"], extra:[[["Input Map"],"Detect the player's interaction action."],[["Signal"],"Notify another object that the interaction happened."]] }
  ];

  function basicStem(word) {
    if (word.length > 5 && word.endsWith("ing")) return word.slice(0, -3);
    if (word.length > 4 && word.endsWith("ied")) return `${word.slice(0, -3)}y`;
    if (word.length > 4 && word.endsWith("ed")) return word.slice(0, -2);
    if (word.length > 4 && word.endsWith("es")) return word.slice(0, -2);
    if (word.length > 3 && word.endsWith("s") && !word.endsWith("ss") && !word.endsWith("us") && !word.endsWith("is")) return word.slice(0, -1);
    return word;
  }

  function normalize(text) {
    return String(text || "")
      .toLowerCase()
      .replace(/[^a-z0-9+/#]+/g, " ")
      .replace(/\s+/g, " ")
      .trim();
  }

  function tokens(text) {
    return normalize(text).split(" ").filter(Boolean).map(basicStem);
  }

  function levenshtein(a, b) {
    if (a === b) return 0;
    if (!a.length) return b.length;
    if (!b.length) return a.length;
    const row = Array.from({ length: b.length + 1 }, (_, i) => i);
    for (let i = 1; i <= a.length; i += 1) {
      let previous = row[0]; row[0] = i;
      for (let j = 1; j <= b.length; j += 1) {
        const saved = row[j];
        row[j] = Math.min(row[j] + 1, row[j - 1] + 1, previous + (a[i - 1] === b[j - 1] ? 0 : 1));
        previous = saved;
      }
    }
    return row[b.length];
  }

  function termMatches(query, queryTokens, term) {
    const normalizedTerm = normalize(term);
    if (!normalizedTerm) return false;
    if (query.includes(normalizedTerm)) return true;
    if (normalizedTerm.includes(" ")) {
      const phraseWords = normalizedTerm.split(" ").map(basicStem).filter((word) => word.length >= 4);
      if (!phraseWords.length) return false;
      return phraseWords.every((word) => queryTokens.some((token) => {
        if (token === word) return true;
        if (token.length < 5 || word.length < 5) return false;
        const limit = Math.max(token.length, word.length) >= 8 ? 2 : 1;
        return levenshtein(token, word) <= limit;
      }));
    }
    const stem = basicStem(normalizedTerm);
    return queryTokens.some((token) => {
      if (token === stem) return true;
      if (token.length >= 4 && stem.length >= 4 && (token.startsWith(stem) || stem.startsWith(token)) && Math.abs(token.length - stem.length) <= 2) return true;
      if (token.length < 5 || stem.length < 5) return false;
      const limit = Math.max(token.length, stem.length) >= 8 ? 2 : 1;
      return levenshtein(token, stem) <= limit;
    });
  }

  function mechanicPhraseMatches(query, queryTokens, phrase) {
    const normalizedPhrase = normalize(phrase);
    if (!normalizedPhrase) return false;
    if (query.includes(normalizedPhrase)) return true;

    // Mechanic phrases are intentionally stricter than the broad vocabulary
    // matcher. Keep short but meaningful words such as "npc", "gun", "key",
    // and "win" so a phrase cannot accidentally collapse to just "player".
    const phraseTokens = tokens(normalizedPhrase).filter((word) => !STOP_WORDS.has(word) && word.length >= 2);
    if (!phraseTokens.length) return false;
    return phraseTokens.every((word) => queryTokens.some((token) => {
      if (token === word) return true;
      if (token.length < 5 || word.length < 5) return false;
      const limit = Math.max(token.length, word.length) >= 8 ? 2 : 1;
      return levenshtein(token, word) <= limit;
    }));
  }

  function detectDomain(query) {
    if (/\b(2d|sprite|node2d|characterbody2d)\b/.test(query)) return "2D";
    if (/\b(ui|hud|interface|control node|controlnode)\b/.test(query)) return "UI";
    if (/\b(3d|node3d|characterbody3d)\b/.test(query)) return "3D";
    return "";
  }

  function itemMatchesDomain(item, domain) {
    if (!domain) return true;
    return item.label.toUpperCase().includes(domain);
  }

  function defaultDomainPriority(item) {
    const label = String(item.label || "").toUpperCase();
    // Logic Bricks began as a 3D tool, so dimension-neutral searches prefer
    // the 3D documentation copy. Explicit 2D/3D/UI queries still override
    // this completely through detectDomain() + itemMatchesDomain().
    if (label.includes("3D")) return 3;
    if (label.includes("2D")) return 2;
    if (label.includes("UI")) return 1;
    return 0;
  }

  function pickIndexItem(index, names, domain) {
    let available = names.flatMap((name, nameOrder) => index
      .filter((item) => item.label !== "Page" && item.title === name)
      .map((item) => ({ item, nameOrder })));
    if (!available.length) return null;

    // An explicit 2D/3D/UI query is a hard constraint. Never recommend a
    // brick from a different domain just because its wording scored well.
    if (domain) {
      available = available.filter(({ item }) => itemMatchesDomain(item, domain));
      if (!available.length) return null;
    }

    available.sort((a, b) => {
      if (!domain) {
        const domainDifference = defaultDomainPriority(b.item) - defaultDomainPriority(a.item);
        if (domainDifference) return domainDifference;
      }
      if (a.nameOrder !== b.nameOrder) return a.nameOrder - b.nameOrder;
      return a.item.label.localeCompare(b.item.label);
    });
    return available[0].item;
  }

  function getSuggestions(queryText, index, limit = 6) {
    const query = normalize(queryText);
    if (!query) return [];
    const queryTokens = tokens(query).filter((word) => !STOP_WORDS.has(word));
    const domain = detectDomain(query);

    // A role word by itself describes a kind of character, not a complete behavior.
    // Keep these searches focused; additional action words (chase, shoot, health, etc.)
    // activate the richer intent combinations below.
    const roleWords = new Set(["character","player","enemy","npc","monster","creature","hero","avatar","opponent","boss"]);
    const roleNoise = new Set(["2d","3d"]);
    const meaningfulRoleTokens = queryTokens.filter((word) => !roleNoise.has(word));
    if (meaningfulRoleTokens.length === 1 && roleWords.has(meaningfulRoleTokens[0])) {
      const roleSuggestions = [
        [["Character Physics"],"Apply 3D character movement and physics each frame."],
        [["Character 2D Physics"],"Apply 2D character movement and physics each frame."],
        [["Character Jump"],"Add jumping behavior to a 3D character."],
        [["Character Jump 2D"],"Add jumping behavior to a 2D character."]
      ];
      return roleSuggestions
        .map(([names, reason]) => ({ item: pickIndexItem(index, names, domain), reason }))
        .filter(({ item }) => Boolean(item))
        .sort((a, b) => domain ? 0 : defaultDomainPriority(b.item) - defaultDomainPriority(a.item))
        .slice(0, limit)
        .map(({ item, reason }) => ({ title:item.title, label:item.label, url:item.url, reason, score:20 }));
    }

    const scored = new Map();
    const activated = [];

    const add = (names, reason, points, concept) => {
      const item = pickIndexItem(index, names, domain);
      if (!item) return;
      const key = `${item.title}|${item.url}`;
      const current = scored.get(key) || { item, score:0, reasons:[], concepts:new Set() };
      current.score += points;
      if (reason && !current.reasons.includes(reason)) current.reasons.push(reason);
      if (concept) current.concepts.add(concept);
      scored.set(key, current);
    };

    // Recognize common mechanic phrases before general vocabulary. These
    // deliberately receive a large boost so a phrase such as "moving platform"
    // can outrank generic matches for words like "move" or "platform".
    COMMON_MECHANICS.forEach((mechanic) => {
      const matchedPhrases = mechanic.phrases.filter((phrase) => mechanicPhraseMatches(query, queryTokens, phrase));
      if (!matchedPhrases.length) return;
      const boost = 32 + Math.min(10, matchedPhrases.length * 2);
      mechanic.suggestions.forEach(([names, reason], rank) => add(names, reason, boost - (rank * 2), `mechanic:${mechanic.id}`));
    });

    INTENTS.forEach((intent) => {
      if (intent.id === "chase" && /\bcamera\b/.test(query)) return;
      const hits = intent.terms.filter((term) => termMatches(query, queryTokens, term));
      if (!hits.length) return;
      activated.push(intent.id);
      const boost = 9 + Math.min(6, hits.length * 2);
      intent.suggestions.forEach(([names, reason], rank) => add(names, reason, boost - rank, intent.id));
    });

    RECIPE_BOOSTS.forEach((recipe) => {
      const anyOk = !recipe.any || recipe.any.some((term) => termMatches(query, queryTokens, term));
      const allOk = !recipe.all || recipe.all.every((term) => activated.includes(term) || termMatches(query, queryTokens, term));
      if (anyOk && allOk) recipe.extra.forEach(([names, reason], rank) => add(names, reason, 12 - rank, "recipe"));
    });

    // Documentation text provides broad coverage for concepts not yet in the curated vocabulary.
    index.filter((item) => item.label !== "Page" && itemMatchesDomain(item, domain)).forEach((item) => {
      const title = normalize(item.title);
      const haystack = normalize(`${item.title} ${item.label} ${item.description || ""}`);
      let score = 0;
      queryTokens.forEach((token) => {
        if (token.length < 3) return;
        if (title.includes(token)) score += 5;
        else if (haystack.includes(token)) score += 1.25;
      });
      const directTitleMatch = queryTokens.some((token) => token.length >= 3 && title.includes(token));
      if (score >= 2.5 && scored.size < 3) {
        const key = `${item.title}|${item.url}`;
        const current = scored.get(key) || { item, score:0, reasons:[], concepts:new Set() };
        current.score += Math.min(8, score);
        // For dimension-neutral searches, use 3D as the default tie-breaker
        // without preventing a substantially stronger 2D result from appearing.
        if (!domain && defaultDomainPriority(item) === 3) current.score += 1.5;
        if (!current.reasons.length) current.reasons.push("Its documented capabilities match part of what you described.");
        scored.set(key, current);
      }
    });

    // Prefer a compact set of different bricks instead of repeated domain copies.
    const seenTitles = new Set();
    return [...scored.values()]
      .sort((a, b) => b.score - a.score || b.concepts.size - a.concepts.size || a.item.title.localeCompare(b.item.title))
      .filter((entry) => {
        if (seenTitles.has(entry.item.title)) return false;
        seenTitles.add(entry.item.title);
        return true;
      })
      .slice(0, limit)
      .map((entry) => ({
        title: entry.item.title,
        label: entry.item.label,
        url: entry.item.url,
        reason: entry.reasons[0] || "This brick may help with the behavior you described.",
        score: entry.score
      }));
  }

  window.LOGIC_BRICKS_INTENT = { getSuggestions, normalize };
})();
