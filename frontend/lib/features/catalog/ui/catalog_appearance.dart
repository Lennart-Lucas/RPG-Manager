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

/// Renders Material or Font Awesome catalog icons without clipping FA glyphs.
Widget catalogAppearanceIconWidget(
  IconData icon, {
  double size = 24,
  Color? color,
}) {
  if (catalogAppearanceIsFontAwesome(icon)) {
    return FaIcon(
      FaIconData(icon),
      size: size * 0.85,
      color: color,
    );
  }
  return Icon(icon, size: size, color: color);
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

class CatalogIconColorFields extends StatelessWidget {
  const CatalogIconColorFields({
    super.key,
    required this.iconKey,
    required this.colorArgb,
    required this.fallbackIcon,
    required this.onIconChanged,
    required this.onColorChanged,
  });

  final String iconKey;
  final int? colorArgb;
  final IconData fallbackIcon;
  final ValueChanged<String> onIconChanged;
  final ValueChanged<int?> onColorChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final selectedColor = catalogAppearanceColor(
      colorArgb,
      fallback: scheme.primary,
    );
    final selectedIcon = catalogAppearanceIcon(iconKey, fallback: fallbackIcon);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Icon', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final entry in kCatalogAppearanceIcons)
              InkWell(
                onTap: () => onIconChanged(entry.$1),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: iconKey == entry.$1
                        ? selectedColor.withValues(alpha: 0.22)
                        : scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: iconKey == entry.$1
                          ? selectedColor
                          : scheme.outlineVariant,
                    ),
                  ),
                  child: catalogAppearanceIconWidget(
                    entry.$2,
                    size: 20,
                    color: iconKey == entry.$1
                        ? selectedColor
                        : scheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Text('Color', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final swatch in kCatalogAppearanceSwatches)
              InkWell(
                onTap: () => onColorChanged(catalogAppearanceColorArgb(swatch)),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: swatch,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: colorArgb == catalogAppearanceColorArgb(swatch)
                          ? scheme.onSurface
                          : scheme.outlineVariant,
                      width: colorArgb == catalogAppearanceColorArgb(swatch)
                          ? 2.5
                          : 1,
                    ),
                  ),
                  child: colorArgb == catalogAppearanceColorArgb(swatch)
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
      ],
    );
  }
}
