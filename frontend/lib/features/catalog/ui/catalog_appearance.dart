import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

/// Curated Material + Font Awesome icons for condition / damage-type records.
/// Existing keys must stay stable so saved iconKey values keep resolving.
final kCatalogAppearanceIcons = <(String key, IconData icon, String label)>[
  // Existing (keep order / keys)
  ('favorite', Icons.favorite_outline, 'Heart'),
  ('monitor_heart', Icons.monitor_heart_outlined, 'Vital'),
  ('local_fire_department', Icons.local_fire_department_outlined, 'Fire'),
  ('ac_unit', Icons.ac_unit, 'Cold'),
  ('bolt', Icons.bolt_outlined, 'Lightning'),
  ('water_drop', Icons.water_drop_outlined, 'Acid'),
  ('toxic', Icons.science_outlined, 'Poison'),
  ('psychology', Icons.psychology_outlined, 'Psychic'),
  ('brightness_7', Icons.brightness_7_outlined, 'Radiant'),
  ('dark_mode', Icons.dark_mode_outlined, 'Necrotic'),
  ('hearing_disabled', Icons.hearing_disabled_outlined, 'Thunder'),
  ('landscape', Icons.landscape_outlined, 'Force'),
  ('coronavirus', Icons.coronavirus_outlined, 'Disease'),
  ('visibility_off', Icons.visibility_off_outlined, 'Blind'),
  ('volume_off', Icons.volume_off_outlined, 'Deaf'),
  ('sentiment_very_dissatisfied', Icons.sentiment_very_dissatisfied_outlined, 'Fear'),
  ('hourglass_empty', Icons.hourglass_empty, 'Slow'),
  ('lock', Icons.lock_outline, 'Restrain'),
  ('airline_seat_flat', Icons.airline_seat_flat, 'Prone'),
  ('flash_on', Icons.flash_on_outlined, 'Stun'),
  ('block', Icons.block, 'Paralyze'),
  ('spa', Icons.spa_outlined, 'Charm'),
  ('shield', Icons.shield_outlined, 'Shield'),
  ('swords', Icons.gavel_outlined, 'Weapon'),
  ('auto_awesome', Icons.auto_awesome_outlined, 'Magic'),

  // Senses & awareness
  ('visibility', Icons.visibility_outlined, 'Sight'),
  ('remove_red_eye', Icons.remove_red_eye_outlined, 'Eye'),
  ('hearing', Icons.hearing_outlined, 'Hearing'),
  ('record_voice_over', Icons.record_voice_over_outlined, 'Voice'),
  ('voice_over_off', Icons.voice_over_off_outlined, 'Mute'),
  ('sensors', Icons.sensors, 'Sense'),
  ('sensors_off', Icons.sensors_off, 'Sense Off'),

  // Mind & emotion
  ('memory', Icons.memory, 'Mind'),
  ('face', Icons.face_outlined, 'Face'),
  ('mood', Icons.mood_outlined, 'Mood'),
  ('mood_bad', Icons.mood_bad_outlined, 'Bad Mood'),
  ('sentiment_neutral', Icons.sentiment_neutral_outlined, 'Neutral'),
  ('sentiment_dissatisfied', Icons.sentiment_dissatisfied_outlined, 'Upset'),
  ('psychology_alt', Icons.psychology_alt_outlined, 'Thought'),
  ('self_improvement', Icons.self_improvement, 'Focus'),
  ('crisis_alert', Icons.crisis_alert, 'Crisis'),
  ('report', Icons.report_outlined, 'Alert'),
  ('priority_high', Icons.priority_high, 'Urgent'),
  ('warning', Icons.warning_amber_outlined, 'Warning'),
  ('error', Icons.error_outline, 'Error'),

  // Body & health
  ('sick', Icons.sick_outlined, 'Sick'),
  ('bloodtype', Icons.bloodtype_outlined, 'Blood'),
  ('healing', Icons.healing_outlined, 'Heal'),
  ('medical_services', Icons.medical_services_outlined, 'Medical'),
  ('emergency', Icons.emergency_outlined, 'Emergency'),
  ('health_and_safety', Icons.health_and_safety_outlined, 'Safety'),
  ('vaccines', Icons.vaccines_outlined, 'Cure'),
  ('medication', Icons.medication_outlined, 'Potion'),
  ('hotel', Icons.hotel_outlined, 'Rest'),
  ('bedtime', Icons.bedtime_outlined, 'Sleep'),
  ('airline_seat_individual_suite', Icons.airline_seat_individual_suite, 'Unconscious'),

  // Control & movement
  ('link', Icons.link, 'Grapple'),
  ('link_off', Icons.link_off, 'Break Free'),
  ('do_not_touch', Icons.do_not_touch_outlined, 'No Touch'),
  ('pan_tool', Icons.pan_tool_outlined, 'Hand'),
  ('back_hand', Icons.back_hand_outlined, 'Back Hand'),
  ('front_hand', Icons.front_hand_outlined, 'Front Hand'),
  ('accessibility_new', Icons.accessibility_new, 'Body'),
  ('directions_run', Icons.directions_run, 'Run'),
  ('directions_walk', Icons.directions_walk, 'Walk'),
  ('hiking', Icons.hiking, 'Climb'),
  ('social_distance', Icons.social_distance, 'Distance'),
  ('person_remove', Icons.person_remove_outlined, 'Isolated'),
  ('person_off', Icons.person_off_outlined, 'Absent'),
  ('do_not_disturb', Icons.do_not_disturb_outlined, 'Incapacitated'),
  ('do_not_disturb_on', Icons.do_not_disturb_on_outlined, 'Blocked'),
  ('cancel', Icons.cancel_outlined, 'Cancel'),
  ('stop_circle', Icons.stop_circle_outlined, 'Stop'),
  ('pause_circle', Icons.pause_circle_outlined, 'Pause'),
  ('timelapse', Icons.timelapse, 'Time'),
  ('timer_off', Icons.timer_off_outlined, 'Timer Off'),
  ('sync_problem', Icons.sync_problem, 'Desync'),
  ('frozen', Icons.severe_cold, 'Frozen'),
  ('snowing', Icons.snowing, 'Snow'),

  // Elements & environment
  ('whatshot', Icons.whatshot_outlined, 'Heat'),
  ('tornado', Icons.tornado_outlined, 'Tornado'),
  ('tsunami', Icons.tsunami, 'Wave'),
  ('volcano', Icons.volcano_outlined, 'Volcano'),
  ('storm', Icons.thunderstorm_outlined, 'Storm'),
  ('cloudy_snowing', Icons.cloudy_snowing, 'Blizzard'),
  ('water', Icons.water_outlined, 'Water'),
  ('air', Icons.air, 'Wind'),
  ('cyclone', Icons.cyclone, 'Cyclone'),
  ('flood', Icons.flood_outlined, 'Flood'),
  ('forest', Icons.forest_outlined, 'Forest'),
  ('grass', Icons.grass_outlined, 'Grass'),
  ('park', Icons.park_outlined, 'Nature'),
  ('wb_sunny', Icons.wb_sunny_outlined, 'Sun'),
  ('nightlight', Icons.nightlight_outlined, 'Night'),
  ('flare', Icons.flare, 'Flare'),
  ('star', Icons.star_outline, 'Star'),
  ('blur_on', Icons.blur_on, 'Blur'),
  ('grain', Icons.grain, 'Grain'),
  ('filter_drama', Icons.filter_drama, 'Cloud'),
  ('dehaze', Icons.dehaze, 'Haze'),
  ('foggy', Icons.foggy, 'Fog'),

  // Creatures & pests
  ('pest_control', Icons.pest_control_outlined, 'Pest'),
  ('bug_report', Icons.bug_report_outlined, 'Bug'),
  ('pets', Icons.pets, 'Beast'),
  ('cruelty_free', Icons.cruelty_free, 'Rabbit'),
  ('emoji_nature', Icons.emoji_nature, 'Nature Face'),
  ('dangerous', Icons.dangerous_outlined, 'Danger'),

  // Combat & magic
  ('sports_mma', Icons.sports_mma, 'Fight'),
  ('sports_kabaddi', Icons.sports_kabaddi, 'Shove'),
  ('gps_fixed', Icons.gps_fixed, 'Target'),
  ('my_location', Icons.my_location, 'Locate'),
  ('track_changes', Icons.track_changes, 'Track'),
  ('radar', Icons.radar, 'Detect'),
  ('security', Icons.security, 'Ward'),
  ('gpp_bad', Icons.gpp_bad_outlined, 'Curse'),
  ('gpp_good', Icons.gpp_good_outlined, 'Bless'),
  ('verified_user', Icons.verified_user_outlined, 'Protected'),
  ('hexagon', Icons.hexagon_outlined, 'Hex'),
  ('pentagon', Icons.pentagon_outlined, 'Seal'),
  ('change_history', Icons.change_history, 'Triangle'),
  ('all_inclusive', Icons.all_inclusive, 'Endless'),
  ('bubble_chart', Icons.bubble_chart_outlined, 'Bubbles'),
  ('scatter_plot', Icons.scatter_plot_outlined, 'Scatter'),
  ('waves', Icons.waves, 'Waves'),
  ('graphic_eq', Icons.graphic_eq, 'Resonate'),
  ('cable', Icons.cable, 'Bind'),
  ('handshake', Icons.handshake_outlined, 'Pact'),
  ('balance', Icons.balance_outlined, 'Balance'),
  ('scale', Icons.scale_outlined, 'Scale'),
  ('workspace_premium', Icons.workspace_premium_outlined, 'Mark'),
  ('military_tech', Icons.military_tech_outlined, 'Rank'),
  ('diamond', Icons.diamond_outlined, 'Gem'),
  ('local_florist', Icons.local_florist_outlined, 'Bloom'),
  ('eco', Icons.eco_outlined, 'Life'),
  ('energy_savings_leaf', Icons.energy_savings_leaf_outlined, 'Leaf'),

  // Font Awesome (keys prefixed fa_*; use .data for IconData compatibility)
  ('fa_skull_crossbones', FontAwesomeIcons.skullCrossbones.data, 'Skull Crossbones'),
  ('fa_ghost', FontAwesomeIcons.ghost.data, 'Ghost'),
  ('fa_dragon', FontAwesomeIcons.dragon.data, 'Dragon'),
  ('fa_wand_magic_sparkles', FontAwesomeIcons.wandMagicSparkles.data, 'Wand Sparkles'),
  ('fa_hat_wizard', FontAwesomeIcons.hatWizard.data, 'Wizard Hat'),
  ('fa_handcuffs', FontAwesomeIcons.handcuffs.data, 'Handcuffs'),
  ('fa_biohazard', FontAwesomeIcons.biohazard.data, 'Biohazard'),
  ('fa_virus', FontAwesomeIcons.virus.data, 'Virus'),
  ('fa_brain', FontAwesomeIcons.brain.data, 'Brain'),
  ('fa_face_dizzy', FontAwesomeIcons.faceDizzy.data, 'Dizzy'),
  ('fa_spider', FontAwesomeIcons.spider.data, 'Spider'),
  ('fa_crow', FontAwesomeIcons.crow.data, 'Crow'),
  ('fa_yin_yang', FontAwesomeIcons.yinYang.data, 'Yin Yang'),
  ('fa_book_skull', FontAwesomeIcons.bookSkull.data, 'Book Skull'),
  ('fa_shield_halved', FontAwesomeIcons.shieldHalved.data, 'Shield Half'),
  ('fa_fire_flame_curved', FontAwesomeIcons.fireFlameCurved.data, 'Flame'),
  ('fa_person_falling', FontAwesomeIcons.personFalling.data, 'Falling'),
  ('fa_user_injured', FontAwesomeIcons.userInjured.data, 'Injured'),
  ('fa_bomb', FontAwesomeIcons.bomb.data, 'Bomb'),
  ('fa_explosion', FontAwesomeIcons.explosion.data, 'Explosion'),
  ('fa_ankh', FontAwesomeIcons.ankh.data, 'Ankh'),
  ('fa_mask', FontAwesomeIcons.mask.data, 'Mask'),
  ('fa_feather', FontAwesomeIcons.feather.data, 'Feather'),
  ('fa_paw', FontAwesomeIcons.paw.data, 'Paw'),
  ('fa_icicles', FontAwesomeIcons.icicles.data, 'Icicles'),
  ('fa_hurricane', FontAwesomeIcons.hurricane.data, 'Hurricane'),
  ('fa_radiation', FontAwesomeIcons.radiation.data, 'Radiation'),
  ('fa_hand_fist', FontAwesomeIcons.handFist.data, 'Fist'),
  ('fa_link_slash', FontAwesomeIcons.linkSlash.data, 'Chain Break'),
  ('fa_ban', FontAwesomeIcons.ban.data, 'Ban'),
  ('fa_moon', FontAwesomeIcons.moon.data, 'Moon'),
  ('fa_sun', FontAwesomeIcons.sun.data, 'Sun'),
  ('fa_snowflake', FontAwesomeIcons.snowflake.data, 'Snowflake'),
  ('fa_bolt_lightning', FontAwesomeIcons.boltLightning.data, 'Bolt'),
  ('fa_droplet', FontAwesomeIcons.droplet.data, 'Droplet'),
  ('fa_flask', FontAwesomeIcons.flask.data, 'Flask'),
  ('fa_vial', FontAwesomeIcons.vial.data, 'Vial'),
  ('fa_eye_slash', FontAwesomeIcons.eyeSlash.data, 'Eye Slash'),
  ('fa_ear_deaf', FontAwesomeIcons.earDeaf.data, 'Deaf Ear'),
  ('fa_bed', FontAwesomeIcons.bed.data, 'Bed'),
  ('fa_spa', FontAwesomeIcons.spa.data, 'Lotus'),
  ('fa_infinity', FontAwesomeIcons.infinity.data, 'Infinity'),
  ('fa_volcano', FontAwesomeIcons.volcano.data, 'Volcano FA'),
  ('fa_mountain', FontAwesomeIcons.mountain.data, 'Mountain'),
  ('fa_tree', FontAwesomeIcons.tree.data, 'Tree'),
  ('fa_leaf', FontAwesomeIcons.leaf.data, 'Leaf FA'),
  ('fa_heart_crack', FontAwesomeIcons.heartCrack.data, 'Broken Heart'),
  ('fa_user_slash', FontAwesomeIcons.userSlash.data, 'User Slash'),
  ('fa_users_slash', FontAwesomeIcons.usersSlash.data, 'Users Slash'),
  ('fa_person_running', FontAwesomeIcons.personRunning.data, 'Running'),
  ('fa_person_walking', FontAwesomeIcons.personWalking.data, 'Walking'),
  ('fa_hand_holding_heart', FontAwesomeIcons.handHoldingHeart.data, 'Holding Heart'),
  ('fa_hand_sparkles', FontAwesomeIcons.handSparkles.data, 'Sparkle Hand'),
  ('fa_jedi', FontAwesomeIcons.jedi.data, 'Jedi'),
  ('fa_dungeon', FontAwesomeIcons.dungeon.data, 'Dungeon'),
  ('fa_skull', FontAwesomeIcons.skull.data, 'Skull'),
  ('fa_heart', FontAwesomeIcons.heart.data, 'Heart FA'),
  ('fa_hand_dots', FontAwesomeIcons.handDots.data, 'Hand Dots'),
  ('fa_broom', FontAwesomeIcons.broom.data, 'Broom'),
  ('fa_wand_magic', FontAwesomeIcons.wandMagic.data, 'Wand'),
  ('fa_face_tired', FontAwesomeIcons.faceTired.data, 'Tired'),
  ('fa_face_angry', FontAwesomeIcons.faceAngry.data, 'Angry'),
  ('fa_face_sad_tear', FontAwesomeIcons.faceSadTear.data, 'Sad Tear'),
  ('fa_face_grin_tears', FontAwesomeIcons.faceGrinTears.data, 'Laugh Tear'),
  ('fa_face_meh_blank', FontAwesomeIcons.faceMehBlank.data, 'Blank Face'),
  ('fa_face_rolling_eyes', FontAwesomeIcons.faceRollingEyes.data, 'Eye Roll'),
  ('fa_person_burst', FontAwesomeIcons.personBurst.data, 'Burst'),
  ('fa_person_rays', FontAwesomeIcons.personRays.data, 'Rays'),
  ('fa_person_drowning', FontAwesomeIcons.personDrowning.data, 'Drowning'),
  ('fa_person_circle_exclamation', FontAwesomeIcons.personCircleExclamation.data, 'Person Alert'),
  ('fa_person_circle_xmark', FontAwesomeIcons.personCircleXmark.data, 'Person X'),
  ('fa_person_through_window', FontAwesomeIcons.personThroughWindow.data, 'Through Window'),
  ('fa_person_harassing', FontAwesomeIcons.personHarassing.data, 'Harassing'),
  ('fa_person_praying', FontAwesomeIcons.personPraying.data, 'Praying'),
  ('fa_gem', FontAwesomeIcons.gem.data, 'Gem FA'),
  ('fa_dice_d20', FontAwesomeIcons.diceD20.data, 'D20'),
  ('fa_dice_d6', FontAwesomeIcons.diceD6.data, 'D6'),
  ('fa_chess_knight', FontAwesomeIcons.chessKnight.data, 'Knight'),
  ('fa_scroll', FontAwesomeIcons.scroll.data, 'Scroll'),
  ('fa_book_open', FontAwesomeIcons.bookOpen.data, 'Book Open'),
  ('fa_bone', FontAwesomeIcons.bone.data, 'Bone'),
  ('fa_hand_holding_medical', FontAwesomeIcons.handHoldingMedical.data, 'Medical Hand'),
  ('fa_hand_holding_droplet', FontAwesomeIcons.handHoldingDroplet.data, 'Blood Hand'),
  ('fa_hands_bubbles', FontAwesomeIcons.handsBubbles.data, 'Bubbles Hands'),
  ('fa_hand_back_fist', FontAwesomeIcons.handBackFist.data, 'Back Fist'),
  ('fa_face_flushed', FontAwesomeIcons.faceFlushed.data, 'Flushed'),
  ('fa_face_grimace', FontAwesomeIcons.faceGrimace.data, 'Grimace'),
  ('fa_face_surprise', FontAwesomeIcons.faceSurprise.data, 'Surprise'),
  ('fa_cloud_bolt', FontAwesomeIcons.cloudBolt.data, 'Storm Cloud'),
  ('fa_cloud_rain', FontAwesomeIcons.cloudRain.data, 'Rain'),
  ('fa_wind', FontAwesomeIcons.wind.data, 'Wind FA'),
  ('fa_tornado', FontAwesomeIcons.tornado.data, 'Tornado FA'),
  ('fa_temperature_arrow_down', FontAwesomeIcons.temperatureArrowDown.data, 'Temp Down'),
  ('fa_temperature_high', FontAwesomeIcons.temperatureHigh.data, 'Hot'),
  ('fa_fire_flame_simple', FontAwesomeIcons.fireFlameSimple.data, 'Simple Fire'),
  ('fa_house_crack', FontAwesomeIcons.houseCrack.data, 'House Crack'),
  ('fa_house_tsunami', FontAwesomeIcons.houseTsunami.data, 'Tsunami House'),
  ('fa_radiation_circle', FontAwesomeIcons.circleRadiation.data, 'Radiation Circle'),
  ('fa_syringe', FontAwesomeIcons.syringe.data, 'Syringe'),
  ('fa_pills', FontAwesomeIcons.pills.data, 'Pills'),
  ('fa_heart_circle_minus', FontAwesomeIcons.heartCircleMinus.data, 'Heart Minus'),
  ('fa_heart_circle_plus', FontAwesomeIcons.heartCirclePlus.data, 'Heart Plus'),
  ('fa_heart_circle_xmark', FontAwesomeIcons.heartCircleXmark.data, 'Heart X'),
  ('fa_lungs', FontAwesomeIcons.lungs.data, 'Lungs'),
  ('fa_head_side_virus', FontAwesomeIcons.headSideVirus.data, 'Head Virus'),
  ('fa_head_side_cough', FontAwesomeIcons.headSideCough.data, 'Cough'),
  ('fa_head_side_mask', FontAwesomeIcons.headSideMask.data, 'Masked'),
  ('fa_disease', FontAwesomeIcons.disease.data, 'Disease FA'),
  ('fa_bacteria', FontAwesomeIcons.bacteria.data, 'Bacteria'),
  ('fa_mosquito', FontAwesomeIcons.mosquito.data, 'Mosquito'),
  ('fa_locust', FontAwesomeIcons.locust.data, 'Locust'),
  ('fa_snowman', FontAwesomeIcons.snowman.data, 'Snowman'),
  ('fa_staff_snake', FontAwesomeIcons.staffSnake.data, 'Caduceus'),
  ('fa_shield_virus', FontAwesomeIcons.shieldVirus.data, 'Shield Virus'),
  ('fa_shield_heart', FontAwesomeIcons.shieldHeart.data, 'Shield Heart'),
  ('fa_ring', FontAwesomeIcons.ring.data, 'Ring'),
  ('fa_om', FontAwesomeIcons.om.data, 'Om'),
  ('fa_hamsa', FontAwesomeIcons.hamsa.data, 'Hamsa'),
  ('fa_hands_praying', FontAwesomeIcons.handsPraying.data, 'Praying Hands'),
  ('fa_handshake_slash', FontAwesomeIcons.handshakeSlash.data, 'Pact Break'),
  ('fa_hand_peace', FontAwesomeIcons.handPeace.data, 'Peace'),
  ('fa_thumbs_down', FontAwesomeIcons.thumbsDown.data, 'Thumbs Down'),
  ('fa_thumbs_up', FontAwesomeIcons.thumbsUp.data, 'Thumbs Up'),
  ('fa_face_smile_wink', FontAwesomeIcons.faceSmileWink.data, 'Wink'),
  ('fa_face_frown', FontAwesomeIcons.faceFrown.data, 'Frown'),
  ('fa_cloud_moon', FontAwesomeIcons.cloudMoon.data, 'Cloud Moon'),
  ('fa_cloud_sun', FontAwesomeIcons.cloudSun.data, 'Cloud Sun'),
  ('fa_cloud_showers_heavy', FontAwesomeIcons.cloudShowersHeavy.data, 'Downpour'),
  ('fa_temperature_arrow_up', FontAwesomeIcons.temperatureArrowUp.data, 'Temp Up'),
  ('fa_temperature_low', FontAwesomeIcons.temperatureLow.data, 'Cold FA'),
  ('fa_fire_burner', FontAwesomeIcons.fireBurner.data, 'Burner'),
  ('fa_fire', FontAwesomeIcons.fire.data, 'Fire FA'),
  ('fa_house_fire', FontAwesomeIcons.houseFire.data, 'House Fire'),
  ('fa_head_side_cough_slash', FontAwesomeIcons.headSideCoughSlash.data, 'Cough Slash'),
  ('fa_virus_covid', FontAwesomeIcons.virusCovid.data, 'Covid'),
  ('fa_virus_covid_slash', FontAwesomeIcons.virusCovidSlash.data, 'Covid Clear'),
  ('fa_worm', FontAwesomeIcons.worm.data, 'Worm'),
  ('fa_heart_pulse', FontAwesomeIcons.heartPulse.data, 'Heartbeat'),
  ('fa_joint', FontAwesomeIcons.joint.data, 'Joint'),
  ('fa_bandage', FontAwesomeIcons.bandage.data, 'Bandage'),
  ('fa_wheelchair', FontAwesomeIcons.wheelchair.data, 'Wheelchair'),
  ('fa_wheelchair_move', FontAwesomeIcons.wheelchairMove.data, 'Wheel Move'),
  ('fa_person_cane', FontAwesomeIcons.personCane.data, 'Cane'),
  ('fa_person_circle_check', FontAwesomeIcons.personCircleCheck.data, 'Person Check'),
  ('fa_person_circle_minus', FontAwesomeIcons.personCircleMinus.data, 'Person Minus'),
  ('fa_person_circle_plus', FontAwesomeIcons.personCirclePlus.data, 'Person Plus'),
  ('fa_person_circle_question', FontAwesomeIcons.personCircleQuestion.data, 'Person ?'),
  ('fa_face_kiss_wink_heart', FontAwesomeIcons.faceKissWinkHeart.data, 'Kiss'),
  ('fa_face_grin_beam_sweat', FontAwesomeIcons.faceGrinBeamSweat.data, 'Sweat Grin'),
  ('fa_face_frown_open', FontAwesomeIcons.faceFrownOpen.data, 'Open Frown'),
  ('fa_face_meh', FontAwesomeIcons.faceMeh.data, 'Meh'),
  ('fa_face_grin_squint_tears', FontAwesomeIcons.faceGrinSquintTears.data, 'Cry Laugh'),
  ('fa_hand_point_up', FontAwesomeIcons.handPointUp.data, 'Point Up'),
  ('fa_hand_point_down', FontAwesomeIcons.handPointDown.data, 'Point Down'),
  ('fa_hands_holding_circle', FontAwesomeIcons.handsHoldingCircle.data, 'Hold Circle'),
  ('fa_book_medical', FontAwesomeIcons.bookMedical.data, 'Medical Book'),
  ('fa_person_falling_burst', FontAwesomeIcons.personFallingBurst.data, 'Fall Burst'),
  ('fa_person_shelter', FontAwesomeIcons.personShelter.data, 'Shelter'),
  ('fa_house_medical_circle_xmark', FontAwesomeIcons.houseMedicalCircleXmark.data, 'Med House X'),
  ('fa_house_circle_exclamation', FontAwesomeIcons.houseCircleExclamation.data, 'House Alert'),
  ('fa_house_lock', FontAwesomeIcons.houseLock.data, 'House Lock'),
  ('fa_hill_rockslide', FontAwesomeIcons.hillRockslide.data, 'Rockslide'),
  ('fa_book_journal_whills', FontAwesomeIcons.bookJournalWhills.data, 'Whills'),
  ('fa_spaghetti_monster_flying', FontAwesomeIcons.spaghettiMonsterFlying.data, 'Flying Spaghetti'),
  ('fa_frog', FontAwesomeIcons.frog.data, 'Frog'),
  ('fa_dove', FontAwesomeIcons.dove.data, 'Dove'),
  ('fa_cat', FontAwesomeIcons.cat.data, 'Cat'),
  ('fa_dog', FontAwesomeIcons.dog.data, 'Dog'),
];

bool catalogAppearanceIsFontAwesome(IconData icon) =>
    icon.fontPackage == 'font_awesome_flutter';

/// Keys offered in the condition icon picker (subset of [kCatalogAppearanceIcons]).
/// Saved keys outside this set still resolve via [catalogAppearanceIcon].
const kConditionAppearanceIconKeys = <String>{
  // Core / classic conditions
  'favorite',
  'monitor_heart',
  'local_fire_department',
  'ac_unit',
  'bolt',
  'water_drop',
  'toxic',
  'psychology',
  'brightness_7',
  'dark_mode',
  'hearing_disabled',
  'landscape',
  'coronavirus',
  'visibility_off',
  'volume_off',
  'sentiment_very_dissatisfied',
  'hourglass_empty',
  'lock',
  'airline_seat_flat',
  'flash_on',
  'block',
  'spa',
  'shield',
  'auto_awesome',
  // Senses
  'visibility',
  'remove_red_eye',
  'hearing',
  'record_voice_over',
  'voice_over_off',
  'sensors',
  'sensors_off',
  // Mind / emotion
  'memory',
  'face',
  'mood',
  'mood_bad',
  'sentiment_neutral',
  'sentiment_dissatisfied',
  'psychology_alt',
  'self_improvement',
  'crisis_alert',
  'warning',
  'error',
  // Body / health
  'sick',
  'bloodtype',
  'healing',
  'medical_services',
  'emergency',
  'health_and_safety',
  'vaccines',
  'medication',
  'hotel',
  'bedtime',
  'airline_seat_individual_suite',
  // Control / movement
  'link',
  'link_off',
  'do_not_touch',
  'pan_tool',
  'accessibility_new',
  'directions_run',
  'directions_walk',
  'person_remove',
  'person_off',
  'do_not_disturb',
  'do_not_disturb_on',
  'cancel',
  'stop_circle',
  'pause_circle',
  'timelapse',
  'timer_off',
  'frozen',
  'snowing',
  // Atmosphere / status
  'whatshot',
  'tornado',
  'storm',
  'cloudy_snowing',
  'air',
  'cyclone',
  'wb_sunny',
  'nightlight',
  'blur_on',
  'foggy',
  'dehaze',
  'pest_control',
  'bug_report',
  'dangerous',
  'gpp_bad',
  'gpp_good',
  'verified_user',
  'hexagon',
  'all_inclusive',
  'waves',
  'graphic_eq',
  'cable',
  'balance',
  // Font Awesome — status / affliction themed
  'fa_skull_crossbones',
  'fa_ghost',
  'fa_handcuffs',
  'fa_biohazard',
  'fa_virus',
  'fa_brain',
  'fa_face_dizzy',
  'fa_spider',
  'fa_yin_yang',
  'fa_book_skull',
  'fa_shield_halved',
  'fa_fire_flame_curved',
  'fa_person_falling',
  'fa_user_injured',
  'fa_mask',
  'fa_icicles',
  'fa_hurricane',
  'fa_radiation',
  'fa_hand_fist',
  'fa_link_slash',
  'fa_ban',
  'fa_moon',
  'fa_sun',
  'fa_snowflake',
  'fa_bolt_lightning',
  'fa_droplet',
  'fa_flask',
  'fa_vial',
  'fa_eye_slash',
  'fa_ear_deaf',
  'fa_bed',
  'fa_spa',
  'fa_infinity',
  'fa_heart_crack',
  'fa_user_slash',
  'fa_users_slash',
  'fa_person_running',
  'fa_person_walking',
  'fa_hand_holding_heart',
  'fa_hand_sparkles',
  'fa_skull',
  'fa_heart',
  'fa_hand_dots',
  'fa_wand_magic',
  'fa_wand_magic_sparkles',
  'fa_face_tired',
  'fa_face_angry',
  'fa_face_sad_tear',
  'fa_face_meh_blank',
  'fa_face_rolling_eyes',
  'fa_person_burst',
  'fa_person_rays',
  'fa_person_drowning',
  'fa_person_circle_exclamation',
  'fa_person_circle_xmark',
  'fa_person_praying',
  'fa_bone',
  'fa_hand_holding_medical',
  'fa_hand_holding_droplet',
  'fa_hand_back_fist',
  'fa_face_flushed',
  'fa_face_grimace',
  'fa_face_surprise',
  'fa_cloud_bolt',
  'fa_wind',
  'fa_tornado',
  'fa_temperature_arrow_down',
  'fa_temperature_high',
  'fa_temperature_low',
  'fa_fire_flame_simple',
  'fa_fire',
  'fa_radiation_circle',
  'fa_syringe',
  'fa_pills',
  'fa_heart_circle_minus',
  'fa_heart_circle_plus',
  'fa_heart_circle_xmark',
  'fa_lungs',
  'fa_head_side_virus',
  'fa_head_side_cough',
  'fa_head_side_mask',
  'fa_disease',
  'fa_bacteria',
  'fa_mosquito',
  'fa_staff_snake',
  'fa_shield_virus',
  'fa_shield_heart',
  'fa_handshake_slash',
  'fa_face_frown',
  'fa_face_frown_open',
  'fa_face_meh',
  'fa_face_grin_beam_sweat',
  'fa_heart_pulse',
  'fa_joint',
  'fa_bandage',
  'fa_wheelchair',
  'fa_wheelchair_move',
  'fa_person_cane',
  'fa_person_circle_minus',
  'fa_person_circle_plus',
  'fa_person_falling_burst',
  'fa_person_shelter',
  'fa_head_side_cough_slash',
  'fa_virus_covid',
  'fa_virus_covid_slash',
  'fa_ankh',
  'fa_feather',
};

/// Condition picker entries in [kCatalogAppearanceIcons] order.
List<(String key, IconData icon, String label)> get kConditionAppearanceIcons =>
    [
      for (final entry in kCatalogAppearanceIcons)
        if (kConditionAppearanceIconKeys.contains(entry.$1)) entry,
    ];

/// Renders Material or Font Awesome catalog icons, centered in a square.
Widget catalogAppearanceIconWidget(
  IconData icon, {
  double size = 24,
  Color? color,
}) {
  final Widget glyph;
  if (catalogAppearanceIsFontAwesome(icon)) {
    glyph = FaIcon(
      FaIconData(icon),
      size: size * 0.82,
      color: color,
    );
  } else {
    glyph = Icon(icon, size: size, color: color);
  }
  return SizedBox(
    width: size,
    height: size,
    child: Center(child: glyph),
  );
}

IconData catalogAppearanceIcon(String? key, {IconData fallback = Icons.circle_outlined}) {
  if (key == null || key.isEmpty) return fallback;
  for (final entry in kCatalogAppearanceIcons) {
    if (entry.$1 == key) return entry.$2;
  }
  return fallback;
}

Color catalogAppearanceColor(int? argb, {required Color fallback}) {
  if (argb == null) return fallback;
  return Color(argb);
}

int catalogAppearanceColorArgb(Color color) =>
    ((color.a * 255).round() << 24) |
    ((color.r * 255).round() << 16) |
    ((color.g * 255).round() << 8) |
    (color.b * 255).round();

const kCatalogAppearanceSwatches = <Color>[
  Color(0xFFE53935),
  Color(0xFFD81B60),
  Color(0xFF8E24AA),
  Color(0xFF5E35B1),
  Color(0xFF3949AB),
  Color(0xFF1E88E5),
  Color(0xFF039BE5),
  Color(0xFF00ACC1),
  Color(0xFF00897B),
  Color(0xFF43A047),
  Color(0xFF7CB342),
  Color(0xFFC0CA33),
  Color(0xFFFDD835),
  Color(0xFFFFB300),
  Color(0xFFFB8C00),
  Color(0xFFF4511E),
  Color(0xFF6D4C41),
  Color(0xFF546E7A),
  Color(0xFF78909C),
  Color(0xFF37474F),
];

typedef CatalogAppearanceIconEntry = (String key, IconData icon, String label);

Future<({String iconKey, int? colorArgb})?> showCatalogAppearancePicker({
  required BuildContext context,
  required String iconKey,
  required int? colorArgb,
  required IconData fallbackIcon,
  List<CatalogAppearanceIconEntry>? icons,
  String title = 'Icon & color',
}) {
  return showModalBottomSheet<({String iconKey, int? colorArgb})>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) {
      return _CatalogAppearancePickerSheet(
        initialIconKey: iconKey,
        initialColorArgb: colorArgb,
        fallbackIcon: fallbackIcon,
        icons: icons ?? kCatalogAppearanceIcons,
        title: title,
      );
    },
  );
}

class _CatalogAppearancePickerSheet extends StatefulWidget {
  const _CatalogAppearancePickerSheet({
    required this.initialIconKey,
    required this.initialColorArgb,
    required this.fallbackIcon,
    required this.icons,
    required this.title,
  });

  final String initialIconKey;
  final int? initialColorArgb;
  final IconData fallbackIcon;
  final List<CatalogAppearanceIconEntry> icons;
  final String title;

  @override
  State<_CatalogAppearancePickerSheet> createState() =>
      _CatalogAppearancePickerSheetState();
}

class _CatalogAppearancePickerSheetState
    extends State<_CatalogAppearancePickerSheet> {
  late String _iconKey = widget.initialIconKey;
  late int? _colorArgb = widget.initialColorArgb;
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<CatalogAppearanceIconEntry> get _filtered {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) return widget.icons;
    return [
      for (final entry in widget.icons)
        if (entry.$1.contains(q) || entry.$3.toLowerCase().contains(q)) entry,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final selectedColor = catalogAppearanceColor(
      _colorArgb,
      fallback: scheme.primary,
    );
    final selectedIcon = catalogAppearanceIcon(
      _iconKey,
      fallback: widget.fallbackIcon,
    );
    final filtered = _filtered;
    final maxH = MediaQuery.sizeOf(context).height * 0.88;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: maxH,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(
                      context,
                      (iconKey: _iconKey, colorArgb: _colorArgb),
                    ),
                    child: const Text('Done'),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: selectedColor.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: selectedColor.withValues(alpha: 0.45),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: catalogAppearanceIconWidget(
                      selectedIcon,
                      size: 28,
                      color: selectedColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Preview',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text('Color', style: Theme.of(context).textTheme.titleSmall),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final swatch in kCatalogAppearanceSwatches)
                    InkWell(
                      onTap: () => setState(
                        () => _colorArgb = catalogAppearanceColorArgb(swatch),
                      ),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        width: 32,
                        height: 32,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: swatch,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _colorArgb ==
                                    catalogAppearanceColorArgb(swatch)
                                ? scheme.onSurface
                                : scheme.outlineVariant,
                            width: _colorArgb ==
                                    catalogAppearanceColorArgb(swatch)
                                ? 2.5
                                : 1,
                          ),
                        ),
                        child: _colorArgb == catalogAppearanceColorArgb(swatch)
                            ? catalogAppearanceIconWidget(
                                selectedIcon,
                                size: 14,
                                color: Colors.white,
                              )
                            : null,
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Search icons',
                  hintText: 'Name or keyword',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        'No icons match your search.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 64,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        childAspectRatio: 1,
                      ),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final entry = filtered[index];
                        final selected = _iconKey == entry.$1;
                        return Tooltip(
                          message: entry.$3,
                          child: InkWell(
                            onTap: () => setState(() => _iconKey = entry.$1),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: selected
                                    ? selectedColor.withValues(alpha: 0.22)
                                    : scheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: selected
                                      ? selectedColor
                                      : scheme.outlineVariant,
                                  width: selected ? 2 : 1,
                                ),
                              ),
                              child: catalogAppearanceIconWidget(
                                entry.$2,
                                size: 22,
                                color: selected
                                    ? selectedColor
                                    : scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact form control: preview + button that opens [showCatalogAppearancePicker].
class CatalogIconColorFields extends StatelessWidget {
  const CatalogIconColorFields({
    super.key,
    required this.iconKey,
    required this.colorArgb,
    required this.fallbackIcon,
    required this.onIconChanged,
    required this.onColorChanged,
    this.icons,
    this.pickerTitle = 'Icon & color',
  });

  final String iconKey;
  final int? colorArgb;
  final IconData fallbackIcon;
  final ValueChanged<String> onIconChanged;
  final ValueChanged<int?> onColorChanged;
  final List<CatalogAppearanceIconEntry>? icons;
  final String pickerTitle;

  Future<void> _openPicker(BuildContext context) async {
    final result = await showCatalogAppearancePicker(
      context: context,
      iconKey: iconKey,
      colorArgb: colorArgb,
      fallbackIcon: fallbackIcon,
      icons: icons,
      title: pickerTitle,
    );
    if (result == null) return;
    onIconChanged(result.iconKey);
    onColorChanged(result.colorArgb);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final selectedColor = catalogAppearanceColor(
      colorArgb,
      fallback: scheme.primary,
    );
    final selectedIcon = catalogAppearanceIcon(iconKey, fallback: fallbackIcon);
    String? label;
    for (final entry in icons ?? kCatalogAppearanceIcons) {
      if (entry.$1 == iconKey) {
        label = entry.$3;
        break;
      }
    }
    label ??= 'Custom';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Appearance', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Material(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: () => _openPicker(context),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selectedColor.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selectedColor.withValues(alpha: 0.4),
                      ),
                    ),
                    child: catalogAppearanceIconWidget(
                      selectedIcon,
                      size: 24,
                      color: selectedColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Tap to choose icon and color',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.palette_outlined, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
