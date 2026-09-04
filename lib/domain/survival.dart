import 'package:flutter/material.dart';

import 'package:trip_planner/core/fuzzy.dart';

/// Something that has gone wrong on a trip and needs answering now.
enum Emergency {
  fire('Fire with no matches', 'Light one from a car, a battery or the sun'),
  fuel('Out of fuel', 'Find a pump, work out your range, get help'),
  stuck('Stuck in mud, snow or sand', 'Get the car moving without wrecking it'),
  breakdown('Breakdown on the road', 'Puncture, overheating, failing brakes'),
  blocked('Landslide or blocked road', 'Judge it, wait it out, turn back safely'),
  lost('Lost, no idea where I am', 'Stop moving and work the problem'),
  noSignal('No phone signal', 'Ways to still get a message out'),
  cold('Freezing cold', 'Hypothermia and frostbite'),
  heat('Heatstroke', 'Too hot, too dry, no shade'),
  altitude('Altitude sickness', 'Headache and sickness up high'),
  water('No drinking water', 'Find it, then make it safe'),
  night('Caught out after dark', 'Shelter until light'),
  storm('Storm or flash flood', 'Rain, lightning, rising water'),
  bite('Snake or dog bite', 'What to do and what never to do'),
  injury('A bad fall or bleeding', 'First aid until help arrives');

  const Emergency(this.title, this.subtitle);

  final String title;
  final String subtitle;
}

/// One numbered thing to do, in the order to do it.
class GuideStep {
  const GuideStep(this.title, this.detail);

  final String title;
  final String detail;
}

/// What to do about one [Emergency].
///
/// Deliberately shaped as "the one thing first, then a list": a person reading
/// this is cold, frightened or in the dark, and will not read a paragraph.
class SurvivalGuide {
  const SurvivalGuide({
    required this.kind,
    required this.icon,
    required this.firstThing,
    required this.steps,
    required this.never,
    required this.callFor,
    required this.keywords,
    this.note,
  });

  final Emergency kind;
  final IconData icon;

  /// The single most important action, before any list.
  final String firstThing;

  final List<GuideStep> steps;

  /// Things that get people killed. Kept separate from the steps so they cannot
  /// be skimmed past as just another instruction.
  final List<String> never;

  /// When this becomes someone else's job, and whose.
  final String callFor;

  /// An honest limit of the advice, where there is one.
  final String? note;

  /// Words that should bring this guide up when typed into the assistant.
  final List<String> keywords;

  String get title => kind.title;
  String get subtitle => kind.subtitle;
}

/// A number worth having when there is no signal to look one up.
class RescueNumber {
  const RescueNumber({
    required this.number,
    required this.who,
    required this.what,
    required this.icon,
  });

  final String number;
  final String who;
  final String what;
  final IconData icon;
}

/// Offline emergency guidance, held as data rather than fetched.
///
/// The whole point is that it works with no signal, flat in the middle of a
/// valley, which is exactly where a trip goes wrong. Nothing here calls out to
/// anything; the only part of the emergency feature that needs a network is
/// finding the nearest petrol pump, and that says so when it cannot.
class Survival {
  const Survival._();

  /// Verified against the National Highways and Motorway Police and Rescue 1122
  /// published numbers, September 2026.
  static const List<RescueNumber> rescueNumbers = [
    RescueNumber(
      number: '1122',
      who: 'Rescue 1122',
      what: 'Ambulance, fire and mountain rescue. The one to call first.',
      icon: Icons.emergency_rounded,
    ),
    RescueNumber(
      number: '130',
      who: 'Motorway Police',
      what: 'Anything on a motorway or national highway — a breakdown, '
          'an empty tank, an accident. They patrol and they come out.',
      icon: Icons.local_police_rounded,
    ),
    RescueNumber(
      number: '15',
      who: 'Police',
      what: 'Crime, threats, or when you cannot reach anyone else.',
      icon: Icons.shield_rounded,
    ),
    RescueNumber(
      number: '115',
      who: 'Edhi Ambulance',
      what: 'Ambulance countrywide, including places 1122 has not reached.',
      icon: Icons.medical_services_rounded,
    ),
    RescueNumber(
      number: '16',
      who: 'Fire Brigade',
      what: 'Fire and explosion.',
      icon: Icons.local_fire_department_rounded,
    ),
  ];

  /// Rescue 1122 runs in Punjab, KP, Sindh, Balochistan, Gilgit-Baltistan and
  /// Azad Kashmir, but a remote valley may be hours from the nearest station.
  static const String coverageNote =
      'These numbers work from any phone, even with no credit, as long as some '
      'network reaches you. On a motorway or highway, 130 is usually the fastest '
      'answer. High in the mountains, nobody may be within hours — which is why '
      'the steps below assume you are on your own for a while.';

  static const List<SurvivalGuide> guides = [
    // ---- Fire ------------------------------------------------------------
    SurvivalGuide(
      kind: Emergency.fire,
      icon: Icons.local_fire_department_rounded,
      firstThing: 'Build the fire completely before you make a single spark. '
          'Tinder, then twigs, then wood, all in reach. A spark landing on '
          'nothing is a spark wasted, and you may only get one.',
      steps: [
        GuideStep(
          'Make a tinder nest first',
          'Tissue, cotton wool, a cotton bud, dry grass, pine needles, bark '
              'shavings, pocket lint, or a strip torn off a cotton shirt. Fluff '
              'it into a bird\'s nest about the size of your fist. Dry only — '
              'damp tinder will glow and die.',
        ),
        GuideStep(
          'The car lighter socket, if the car runs',
          'Push the cigarette lighter in and wait for it to pop out. Press the '
              'glowing coil into the middle of the nest and blow gently and '
              'steadily. This is the fastest way there is. If the socket has no '
              'lighter, a phone charger will not do it — go to the next step.',
        ),
        GuideStep(
          'Any battery across steel wool',
          'Rub both terminals of a battery — car, torch, AA, or a power bank '
              'output — across fine steel wool, the kitchen scourer kind. It '
              'catches in seconds. Drop the burning wool into the nest. A foil '
              'chewing-gum or biscuit wrapper cut narrow in the middle does the '
              'same across an AA battery: the thin waist glows and lights.',
        ),
        GuideStep(
          'Jumper cables off the car battery',
          'Clamp to the battery, hold the two free ends over the tinder and '
              'tap them together. Keep your face back and do it away from the '
              'battery itself, which gives off hydrogen.',
        ),
        GuideStep(
          'Hand sanitiser, perfume or spirit',
          'Alcohol-based gel burns and works as tinder in its own right. '
              'Squeeze it onto the nest before you make the spark. Its flame is '
              'almost invisible in daylight, so assume it is lit.',
        ),
        GuideStep(
          'Sunlight through a lens',
          'Spectacles, a camera lens, a magnifying glass, the reflector behind '
              'a torch bulb, or a clear plastic bottle filled with water. Focus '
              'the sun to the smallest, brightest point you can on dark tinder '
              'and hold it dead still. Needs strong sun and a few minutes.',
        ),
        GuideStep(
          'Feed it in three sizes',
          'Matchstick-thin twigs until it is steady, then finger-thick, then '
              'wrist-thick. Leave gaps for air. Piling on big wood too early '
              'smothers more fires than bad tinder does.',
        ),
        GuideStep(
          'Shelter it and keep it',
          'Build against a rock or a bank so wind does not take it, and keep a '
              'pile of dry wood under cover. Relighting is far harder than '
              'feeding.',
        ),
      ],
      never: [
        'Never light or keep a fire inside a tent, a car, or a closed room. '
            'Carbon monoxide has no smell and kills people in their sleep.',
        'Never use petrol to start it. The vapour catches and the flame runs '
            'back to the container in your hand.',
        'Do not build under a snow-loaded or dead branch, or on peat and dry '
            'grass that can carry fire underground.',
      ],
      callFor: 'You do not need rescue to light a fire. But if you are lighting '
          'one because you are lost or too cold, call 1122 now, while you still '
          'have battery and daylight.',
      note: 'A bow drill works, but it takes practice and rarely succeeds when '
          'you are cold, wet and tired. Work through everything above first.',
      keywords: [
        'fire', 'matchstick', 'matchsticks', 'matches', 'lighter', 'flame',
        'light a fire', 'lit the fire', 'lit fire', 'make a fire', 'ignite',
        'campfire', 'bonfire', 'no matches', 'no matchstick', 'start a fire',
      ],
    ),

    // ---- Fuel ------------------------------------------------------------
    SurvivalGuide(
      kind: Emergency.fuel,
      icon: Icons.local_gas_station_rounded,
      firstThing: 'Coast onto the left shoulder while you still have momentum, '
          'hazard lights on, and stay with the vehicle. It is shelter, it is '
          'visible, and it is what anyone looking for you will find first.',
      steps: [
        GuideStep(
          'Call 130 if you are on a motorway or highway',
          'Motorway Police patrol these roads and help stranded drivers, '
              'including getting fuel to you. Give them the nearest kilometre '
              'marker — the small posts at the roadside — and which carriageway '
              'you are on.',
        ),
        GuideStep(
          'Find the nearest pump',
          'Use "Nearest petrol pump" in this screen. It reads your GPS and '
              'lists the pumps around you with the road distance to each, and '
              'will open one in your maps app. It needs a little signal; if '
              'there is none, it falls back to the nearest towns it already '
              'knows about.',
        ),
        GuideStep(
          'Work out what you actually have left',
          'A fuel gauge on empty is not empty — most cars hold five to ten '
              'litres below the light. At your car\'s average that is real '
              'distance. Drive it gently: steady fifty to sixty, no '
              'air conditioning, no hard acceleration, and coast downhill in '
              'gear rather than in neutral.',
        ),
        GuideStep(
          'Going downhill costs almost nothing',
          'If a pump is downhill of you and uphill is empty road, take the '
              'downhill one even if it is further. In mountains this decision '
              'is worth more than the distance difference.',
        ),
        GuideStep(
          'If you have to walk',
          'Daylight only. Walk on the shoulder facing oncoming traffic so you '
              'can see and be seen. Take water, your phone, a torch and warm '
              'clothes. Leave a note on the dashboard with your phone number, '
              'the time you left and which way you went.',
        ),
        GuideStep(
          'Borrowing fuel from another vehicle',
          'Ask at a village or from a stopped truck — a jerrycan and a funnel '
              'are common. Pay for it. If you siphon, use a pump or a squeeze '
              'bulb.',
        ),
      ],
      never: [
        'Never walk on a motorway. It is illegal and it is how people are '
            'killed. Stay with the car and wait for 130.',
        'Never siphon petrol by mouth. Getting it into your lungs causes a '
            'pneumonia that is far more dangerous than the walk you avoided.',
        'Do not sit with the engine running to keep warm if snow or mud can '
            'block the exhaust — the fumes come back inside.',
      ],
      callFor: 'Call 130 on a motorway or national highway. Anywhere else, '
          '1122 will still help you reach someone.',
      keywords: [
        'fuel', 'petrol', 'diesel', 'pump', 'petrol pump', 'filling station',
        'gas station', 'out of fuel', 'no fuel', 'fuel ended', 'fuel finished',
        'tank empty', 'empty tank', 'ran out', 'run out',
      ],
    ),

    // ---- Stuck -----------------------------------------------------------
    SurvivalGuide(
      kind: Emergency.stuck,
      icon: Icons.terrain_rounded,
      firstThing: 'Stop spinning the wheels. Every extra second of wheelspin '
          'digs you deeper and polishes the surface under the tyre into '
          'something nothing will grip.',
      steps: [
        GuideStep(
          'Look before you touch anything',
          'Get out and see which wheels are actually stuck and what they are '
              'sitting in. Clear mud, snow or sand from in front of and behind '
              'the driven wheels, and from under the car if it is resting on '
              'its belly.',
        ),
        GuideStep(
          'Straighten the front wheels',
          'Turned wheels plough. Point them dead ahead before any attempt.',
        ),
        GuideStep(
          'Let some air out of the tyres',
          'Down to about half normal pressure in sand or snow. A softer tyre '
              'spreads out and floats instead of digging. Reinflate at the '
              'first pump — do not drive far or fast on soft tyres.',
        ),
        GuideStep(
          'Give the tyre something to bite',
          'Floor mats, cardboard, branches, flat stones, gravel — wedged hard '
              'up against the tread in the direction you want to go. Stand '
              'clear of the line they will shoot out along.',
        ),
        GuideStep(
          'Rock it out',
          'Second gear, lightest possible throttle. Ease forward to the limit, '
              'let it roll back, forward again — build a rocking rhythm and use '
              'it. In an automatic, shift between drive and reverse only when '
              'the car has actually stopped.',
        ),
        GuideStep(
          'Lighten and push',
          'Everyone out, luggage out. People push from behind the pillars, '
              'never behind the wheels, and never on the downhill side of a '
              'car that could roll.',
        ),
      ],
      never: [
        'Never let anyone stand behind or in front of a car being rocked out. '
            'It leaves suddenly and it does not stop.',
        'Do not keep spinning the wheels in snow — you melt it, it refreezes '
            'as ice, and then nothing works.',
        'Do not crawl under a car resting on soft ground to dig.',
      ],
      callFor: 'If it is getting dark, snowing, or you are on a slope you could '
          'slide down, stop trying and call 1122 or 130.',
      keywords: [
        'stuck', 'bogged', 'mud', 'sand', 'snow stuck', 'ditch', 'wheelspin',
        'wheels spinning', 'cant move car', 'car stuck', 'jeep stuck',
      ],
    ),

    // ---- Breakdown -------------------------------------------------------
    SurvivalGuide(
      kind: Emergency.breakdown,
      icon: Icons.car_repair_rounded,
      firstThing: 'Get off the road. Hazard lights on before you slow down, and '
          'everyone out on the side away from traffic, standing behind the '
          'barrier — not in the car, not on the shoulder.',
      steps: [
        GuideStep(
          'Make yourself visible',
          'Warning triangle a good hundred paces back, further on a bend or '
              'over a crest. At night, a torch or a phone light on the ground '
              'behind it. Being seen matters more than the repair.',
        ),
        GuideStep(
          'Overheating: stop immediately',
          'Pull over and switch off. Do not open the radiator cap while it is '
              'hot — the coolant is above boiling and comes out under pressure. '
              'Wait at least thirty minutes. Turning the heater on full blast '
              'pulls heat out of the engine and can buy you a few kilometres.',
        ),
        GuideStep(
          'Brakes fading on a long descent',
          'Change down and let the engine hold the car. If the pedal is going '
              'soft, stop, pull over and let them cool for twenty minutes — '
              'brakes recover, and riding them the rest of the way down is how '
              'they fail completely. Down from Naran, Babusar or Lowari this is '
              'the single most common way a trip goes wrong.',
        ),
        GuideStep(
          'A puncture with no usable spare',
          'A tyre inflator and sealant fixes a small tread hole well enough to '
              'reach a shop. It will not fix a sidewall cut or a burst. In a '
              'village, ask for the puncture wala — nearly every settlement has '
              'one and they repair rather than replace.',
        ),
        GuideStep(
          'Get the right help coming',
          'On a motorway or highway, 130. Off it, 1122 will reach a local '
              'mechanic faster than you will.',
        ),
      ],
      never: [
        'Never change a wheel on the traffic side of the car, or on a slope, or '
            'with anyone still sitting inside.',
        'Never open a hot radiator cap.',
        'Do not sit inside a broken-down car on a motorway shoulder. Get behind '
            'the barrier.',
      ],
      callFor: 'Call 130 on a motorway or national highway, otherwise 1122.',
      keywords: [
        'breakdown', 'broke down', 'puncture', 'flat tyre', 'flat tire',
        'tyre burst', 'overheat', 'overheating', 'radiator', 'brakes',
        'brake fail', 'engine', 'car not starting', 'battery dead',
      ],
    ),

    // ---- Blocked road ----------------------------------------------------
    SurvivalGuide(
      kind: Emergency.blocked,
      icon: Icons.warning_rounded,
      firstThing: 'Stop well short of it and switch off. A slope that has just '
          'dropped rock is a slope that is about to drop more, and the safest '
          'place is back down the road, not beside it.',
      steps: [
        GuideStep(
          'Reverse out of the fall line',
          'Move back until you are clear of anything above you, then turn '
              'around somewhere wide. Do not park under the cut slope while you '
              'decide.',
        ),
        GuideStep(
          'Do not try to drive across fresh debris',
          'A slide hides holes, and the surface is loose over a drop you cannot '
              'see. Wet slides keep moving for hours.',
        ),
        GuideStep(
          'Find out how long',
          'On the Karakoram Highway and the main valley roads, machinery comes '
              'and clearance is often a few hours. Ask any local driver — they '
              'will know this road and this season better than any app.',
        ),
        GuideStep(
          'Decide before dark',
          'If it will not clear tonight, turn back to the last town with rooms '
              'while there is light. Sleeping in a car below an unstable slope '
              'is the worst of the options.',
        ),
        GuideStep(
          'Report it',
          '130 on a highway, 1122 anywhere. If nobody has called it in, '
              'clearance does not start.',
        ),
      ],
      never: [
        'Never walk across a fresh slide to see what is on the other side.',
        'Never park below a cut slope in rain.',
        'Do not cross a flowing nullah in the car because the road is blocked. '
            'Moving water half a metre deep moves a car.',
      ],
      callFor: 'Report it on 130 or 1122 straight away, even if you turn back.',
      keywords: [
        'landslide', 'land slide', 'rockfall', 'road blocked', 'blocked road',
        'road closed', 'slide', 'avalanche', 'slid off road', 'off the road',
      ],
    ),

    // ---- Lost ------------------------------------------------------------
    SurvivalGuide(
      kind: Emergency.lost,
      icon: Icons.explore_off_rounded,
      firstThing: 'Stop walking. Sit down. Almost everyone who gets into real '
          'trouble does it in the hour after realising they are lost, by '
          'walking fast in the wrong direction.',
      steps: [
        GuideStep(
          'Get your position off your own phone',
          'GPS works with no signal at all — the maps need data, the position '
              'does not. Open this app, or any maps app, and read your '
              'coordinates. Write them down on paper. That one number is what '
              'turns a search into a pickup.',
        ),
        GuideStep(
          'Think back, do not press on',
          'When were you last certain where you were? What did you pass? If '
              'you can retrace to that point in daylight, do. If you cannot, '
              'stay where you are.',
        ),
        GuideStep(
          'Make yourself findable',
          'Open ground, not under trees. Bright clothing spread out. A fire '
              'gives smoke by day and light by night. Three of anything — three '
              'whistle blasts, three torch flashes, three shouts — is the '
              'recognised distress signal.',
        ),
        GuideStep(
          'Downhill and downstream, but only if you must move',
          'Water runs to people. Following a stream down leads to a path, then '
              'a village. But not through a gorge, not over a waterfall lip, '
              'and never in the dark.',
        ),
        GuideStep(
          'Save your battery like it is water',
          'Flight mode between checks — a phone hunting for a signal it cannot '
              'find is the fastest way to flatten it. Screen dim. Keep it warm '
              'in an inside pocket; cold halves a battery.',
        ),
      ],
      never: [
        'Never keep walking after dark to "make progress". Nearly every fall '
            'happens then.',
        'Never split the group up to look for the way.',
        'Do not climb down something you could not climb back up.',
      ],
      callFor: 'Call 1122 as soon as you know you are lost — early, while you '
          'have battery, daylight and a clear head. Give them coordinates.',
      keywords: [
        'lost', 'i am lost', 'we are lost', 'dont know where', 'no idea where',
        'wrong way', 'off track', 'off the trail', 'cant find the way',
        'missing', 'stranded',
      ],
    ),

    // ---- No signal -------------------------------------------------------
    SurvivalGuide(
      kind: Emergency.noSignal,
      icon: Icons.signal_cellular_off_rounded,
      firstThing: 'Try the emergency call anyway. Emergency numbers go out over '
          'any network that reaches you, not only your own, and often connect '
          'where the signal bars show nothing.',
      steps: [
        GuideStep(
          'Go up, and go to the open',
          'Signal comes off ridges and hilltops. A hundred metres of climb, or '
              'stepping out of a valley bottom into open sky, does more than '
              'anything else you can do. Turn the phone off and on again once '
              'you are up there so it searches fresh.',
        ),
        GuideStep(
          'Send a text, not a call',
          'A text needs a fraction of the signal a call does and will keep '
              'retrying by itself. Write it, hit send, and leave the phone '
              'somewhere high with the screen off — it will go the moment a bar '
              'appears.',
        ),
        GuideStep(
          'Put everything in the message',
          'Coordinates, the time, how many of you, who is hurt and how, and '
              'what you have with you. A message that arrives once has to carry '
              'the whole picture.',
        ),
        GuideStep(
          'Ask another network',
          'If anyone with you has a different SIM, try theirs — coverage in the '
              'north differs enormously between operators. A phone with no SIM '
              'at all can still dial an emergency number.',
        ),
        GuideStep(
          'When nothing works, be seen instead',
          'Three of anything is distress: three whistle blasts, three flashes, '
              'three fires in a triangle. Smoke by day, light by night. Green '
              'branches on a fire make white smoke that is visible for miles.',
        ),
      ],
      never: [
        'Do not leave the phone searching for a network for hours. Flight mode '
            'between attempts, or it will be flat when a bar finally appears.',
        'Do not walk further to look for signal if you are hurt or it is '
            'getting dark. Being findable beats being connected.',
      ],
      callFor: 'Keep trying 1122 from high ground. Roaming to another operator '
          'for an emergency call happens automatically.',
      keywords: [
        'no signal', 'no network', 'no coverage', 'cant call', 'no service',
        'phone not working', 'no reception', 'sos',
      ],
    ),

    // ---- Cold ------------------------------------------------------------
    SurvivalGuide(
      kind: Emergency.cold,
      icon: Icons.ac_unit_rounded,
      firstThing: 'Get out of the wind and off the ground before anything else. '
          'The ground pulls heat out of you faster than cold air does, and wind '
          'strips it faster than both.',
      steps: [
        GuideStep(
          'Know what you are looking at',
          'Shivering, clumsy hands, stumbling and slurred speech is '
              'hypothermia setting in. Someone who stops shivering and starts '
              'making no sense is getting worse, not better — that is the point '
              'to treat it as an emergency.',
        ),
        GuideStep(
          'Dry first, then layers',
          'Wet clothes cost you heat many times faster than dry ones. Change '
              'into anything dry even if it is thinner. Insulate underneath — '
              'a rucksack, a rope, branches, a car mat — before you pile things '
              'on top.',
        ),
        GuideStep(
          'Warm from the inside',
          'Warm sweet drinks if they are fully awake and can swallow. Food is '
              'fuel for heat. Share body warmth inside one shelter or sleeping '
              'bag.',
        ),
        GuideStep(
          'Warm the trunk, not the limbs',
          'Chest, neck, armpits, groin. Rubbing cold arms and legs pushes cold '
              'blood back to the heart, which is dangerous in someone badly '
              'chilled.',
        ),
        GuideStep(
          'Frostbitten fingers, ears, nose or toes',
          'White, waxy and numb. Warm them against skin — armpit or belly — or '
              'in water that feels comfortably warm to an unaffected elbow. '
              'Never hot. Rewarm only when you are sure it will not refreeze, '
              'because a second freeze does far worse damage.',
        ),
      ],
      never: [
        'Never give alcohol. It feels warming and it dumps your core heat.',
        'Never rub frostbite, and never thaw it over a fire or a heater — numb '
            'skin cannot feel itself burning.',
        'Do not run a stove or a fire inside a sealed tent or car for warmth.',
      ],
      callFor: 'Confused, drowsy, or shivering has stopped in the cold — 1122 '
          'now. Severe hypothermia is not something to drive out of.',
      keywords: [
        'freezing', 'hypothermia', 'frostbite', 'shivering', 'very cold',
        'too cold', 'cant feel my hands', 'numb', 'frozen',
      ],
    ),

    // ---- Heat ------------------------------------------------------------
    SurvivalGuide(
      kind: Emergency.heat,
      icon: Icons.wb_sunny_rounded,
      firstThing: 'Shade and cooling now, water second. A body that has stopped '
          'sweating and gone confused is minutes-matter serious, not '
          'sit-down-for-a-bit serious.',
      steps: [
        GuideStep(
          'Tell the two apart',
          'Heat exhaustion: heavy sweating, cramps, headache, feeling sick, '
              'clammy skin. Heatstroke: hot dry skin, no sweat, confusion, '
              'staggering, temperature climbing. The second is a medical '
              'emergency.',
        ),
        GuideStep(
          'Get out of the sun',
          'Any shade. If there is none, make it — a sheet or a mat propped up '
              'is better than none, and the inside of a parked car is worse '
              'than the outside.',
        ),
        GuideStep(
          'Cool aggressively',
          'Wet the skin and fan it — evaporation does the work. Cold packs or '
              'wet cloth on neck, armpits and groin. Soaking their clothes is '
              'fine. Keep going until they are making sense again.',
        ),
        GuideStep(
          'Fluids, slowly, only if fully awake',
          'Small sips, often. Water with a little salt and sugar, or a rehydrate '
              'sachet, beats plain water for heavy sweating. Nothing by mouth '
              'for anyone drowsy or confused.',
        ),
        GuideStep(
          'Plan around the middle of the day',
          'In Sindh, southern Punjab, Thar and Gorakh in summer, move early and '
              'late and rest through the middle. Two litres per person per '
              'half day is a starting point, not a maximum.',
        ),
      ],
      never: [
        'Never leave anyone — or a dog — in a parked car. It reaches lethal '
            'temperatures in minutes, even with the windows cracked.',
        'Never give fluids to someone who is confused or drowsy.',
        'Do not wait to see if heatstroke improves. Cool and call at once.',
      ],
      callFor: 'Hot dry skin, confusion or collapse — 1122 immediately, and '
          'start cooling while you wait.',
      keywords: [
        'heatstroke', 'heat stroke', 'sunstroke', 'too hot', 'sunburn',
        'dehydrated', 'dehydration', 'fainted', 'collapsed',
      ],
    ),

    // ---- Altitude --------------------------------------------------------
    SurvivalGuide(
      kind: Emergency.altitude,
      icon: Icons.filter_hdr_rounded,
      firstThing: 'Do not go any higher today. Everything about altitude '
          'sickness gets better going down and worse going up, and there is no '
          'other treatment that comes close.',
      steps: [
        GuideStep(
          'Recognise it',
          'Above roughly 2,500 m: headache plus feeling sick, no appetite, no '
              'sleep, breathless doing nothing. Deosai, Babusar, Khunjerab and '
              'Fairy Meadows are all high enough for this.',
        ),
        GuideStep(
          'Stop and rest',
          'Mild symptoms usually settle in a day at the same height. Drink, '
              'eat, take paracetamol for the headache, and give it time.',
        ),
        GuideStep(
          'Go down for anything worse',
          'Confusion, cannot walk a straight line, breathless at rest, or a '
              'cough with froth. Descend, immediately, even at night, even by '
              'five hundred metres. This is the one situation where moving in '
              'the dark is the right call.',
        ),
        GuideStep(
          'Climb high, sleep low',
          'Khunjerab at 4,700 m in the afternoon is fine if you sleep back down '
              'in Sost or Passu. What you sleep at is what your body has to '
              'cope with.',
        ),
        GuideStep(
          'Give yourself the days',
          'Islamabad to Skardu or Hunza in one push is a big height gain. A '
              'night at Chilas or Gilgit on the way up is worth more than any '
              'medicine.',
        ),
      ],
      never: [
        'Never take someone higher to "push through it".',
        'Never let someone with altitude sickness sleep alone.',
        'Do not use sleeping tablets or alcohol at altitude — both suppress '
            'your breathing while you sleep.',
      ],
      callFor: 'Confused, unsteady, or breathless at rest — start going down '
          'and call 1122 while you move.',
      keywords: [
        'altitude', 'altitude sickness', 'ams', 'mountain sickness',
        'breathless', 'cant breathe', 'high altitude', 'soroche',
      ],
    ),

    // ---- Water -----------------------------------------------------------
    SurvivalGuide(
      kind: Emergency.water,
      icon: Icons.water_drop_rounded,
      firstThing: 'Drink what you have. Water rationed in your bottle does '
          'nothing; water in you keeps you thinking clearly enough to find more.',
      steps: [
        GuideStep(
          'Where it is',
          'Uphill of any village, not below it. Side streams rather than the '
              'main river, which carries everything upstream has put in it. '
              'Green in a dry landscape means water. Snowmelt is cleanest close '
              'to the snow.',
        ),
        GuideStep(
          'Boiling is the one that always works',
          'A rolling boil for one minute, and three minutes above 2,000 m. It '
              'kills everything biological — no filter, no tablets, no doubt.',
        ),
        GuideStep(
          'If you cannot boil',
          'Purification tablets, thirty minutes. Or household bleach with no '
              'additives: two drops per litre of clear water, stir, wait thirty '
              'minutes — it should smell faintly of chlorine. Let cloudy water '
              'settle and pour it off through a cloth first, or nothing will '
              'work properly.',
        ),
        GuideStep(
          'Sunlight, when you have nothing else',
          'A clear plastic bottle filled with clear water, lying on its side in '
              'full sun for six hours, kills most of what makes you ill. All '
              'day if it is cloudy. Last resort, but real.',
        ),
        GuideStep(
          'Slow the loss',
          'Move in the cool hours, rest in shade, keep your mouth shut and '
              'breathe through your nose. Do not eat much if you have very '
              'little water — digestion uses it.',
        ),
      ],
      never: [
        'Never drink from below a village or a camp.',
        'Never drink seawater, urine, or the water out of a car radiator — all '
            'three make it worse.',
        'Do not eat snow to drink. Melt it first; eating it costs you more heat '
            'than the water is worth.',
      ],
      callFor: 'A day without water in heat, or anyone who has stopped passing '
          'urine or gone confused — 1122.',
      keywords: [
        'thirsty', 'no water', 'drinking water', 'purify', 'purify water',
        'clean water', 'safe to drink', 'boil water', 'water is dirty',
      ],
    ),

    // ---- Night -----------------------------------------------------------
    SurvivalGuide(
      kind: Emergency.night,
      icon: Icons.nightlight_round,
      firstThing: 'Decide to stop while you can still see. An hour spent making '
          'a bad camp in daylight beats three hours walking into the dark, and '
          'the decision only gets harder as the light goes.',
      steps: [
        GuideStep(
          'Pick the spot for what it protects you from',
          'Out of the wind, off the ridge, above the valley floor where cold '
              'pools and water rises. Not under dead branches, not in a dry '
              'stream bed, not below a loose slope.',
        ),
        GuideStep(
          'Get off the ground',
          'Anything between you and the earth — branches, dry grass, a rope, a '
              'rucksack, car mats. The ground takes more heat off you all night '
              'than the air does.',
        ),
        GuideStep(
          'The car is a good shelter',
          'Windproof, visible, and everyone in one place. Crack a window a '
              'finger for air. Run the engine for heat only in short bursts, '
              'only with the exhaust clear of snow and mud, and never while '
              'everyone is asleep.',
        ),
        GuideStep(
          'Small fire, close in',
          'A small fire you sit near beats a big one you sit back from, and it '
              'uses a fraction of the wood. Gather more than you think you '
              'need before it gets fully dark.',
        ),
        GuideStep(
          'Tell someone, and be findable',
          'Send your coordinates now while you still have battery. Leave a '
              'torch on facing the way help would come from.',
        ),
      ],
      never: [
        'Never keep walking downhill in the dark to reach a road. Falls happen '
            'here more than anywhere else.',
        'Never sleep with a stove or a fire burning inside a tent or a car.',
        'Do not camp in a dry stream bed. It can be a river within an hour of '
            'rain you cannot even see.',
      ],
      callFor: 'Tell 1122 where you are before dark, even if you do not need '
          'them yet. A position known at dusk is worth hours in the morning.',
      keywords: [
        'after dark', 'in the dark', 'got dark', 'gets dark', 'benighted',
        'stuck at night', 'shelter', 'sleeping outside', 'bivouac',
      ],
    ),

    // ---- Storm -----------------------------------------------------------
    SurvivalGuide(
      kind: Emergency.storm,
      icon: Icons.thunderstorm_rounded,
      firstThing: 'Get away from water and off high ground. In Pakistan\'s '
          'mountains it is not the storm that kills people, it is the water '
          'coming down the nullah half an hour later.',
      steps: [
        GuideStep(
          'Leave the stream bed at once',
          'A flash flood arrives as a wall, from rain you may never have seen, '
              'in a valley you cannot see up. Climb the bank — a few metres of '
              'height is enough, and it needs to happen immediately.',
        ),
        GuideStep(
          'Never drive into moving water',
          'Thirty centimetres floats a car. Sixty carries it away. The road '
              'under it may not be there any more. Turn around; the crossing is '
              'not worth it and it is the single most common way people drown '
              'in a flood.',
        ),
        GuideStep(
          'Lightning: get low, not flat',
          'Off summits and ridges, away from lone trees, metal fences and '
              'poles. Crouch on the balls of your feet with your feet together, '
              'on a mat or a pack if you have one. Spread the group out. Inside '
              'a car is genuinely safe.',
        ),
        GuideStep(
          'Wait it out where you are',
          'Mountain storms usually pass in an hour or two. Roads slide during '
              'and just after the rain, so the hour after it stops is the '
              'dangerous one to drive.',
        ),
        GuideStep(
          'Then reassess the road',
          'Check for new debris and washed-out edges before you set off, and '
              'ask a local driver what the route ahead is doing.',
        ),
      ],
      never: [
        'Never camp in a nullah or a dry stream bed in the monsoon.',
        'Never walk or drive through moving water of unknown depth.',
        'Never shelter under a lone tree or on a summit in lightning.',
      ],
      callFor: 'Cut off by water, or someone swept away — 1122 immediately.',
      keywords: [
        'storm', 'flood', 'flash flood', 'lightning', 'thunder', 'nullah',
        'river rising', 'washed away', 'water rising',
      ],
    ),

    // ---- Bite ------------------------------------------------------------
    SurvivalGuide(
      kind: Emergency.bite,
      icon: Icons.pest_control_rounded,
      firstThing: 'Get away from the animal, keep the person still, and start '
          'moving towards a hospital now. Antivenom and the rabies course are '
          'the treatment; nothing you do at the roadside replaces them.',
      steps: [
        GuideStep(
          'Snake bite: keep them calm and still',
          'Lie them down, keep the bitten limb below heart level and as still '
              'as a broken bone. Panic and movement push venom around. Take '
              'off rings, watches and anything tight before it swells.',
        ),
        GuideStep(
          'Mark the swelling and the time',
          'Draw a line on the skin at the edge of the swelling and write the '
              'time beside it. Repeat every fifteen minutes. That record tells '
              'the hospital how fast it is progressing and it genuinely changes '
              'their treatment.',
        ),
        GuideStep(
          'Get to a hospital with antivenom',
          'A district hospital, not a small clinic. Carry the person to the '
              'vehicle; do not let them walk. Photograph the snake only if it '
              'is already safe to — never go after it.',
        ),
        GuideStep(
          'Dog, cat, monkey or bat bite',
          'Wash the wound with soap under running water for a full fifteen '
              'minutes — it is the single most effective thing anyone does for '
              'rabies. Then a hospital, the same day, for the vaccine. Rabies '
              'once symptoms start cannot be treated.',
        ),
        GuideStep(
          'Avoiding it in the first place',
          'Boots and a torch after dark. Shake out boots and bedding. Do not '
              'put hands into rock cracks or under logs. Step onto rocks, not '
              'over them.',
        ),
      ],
      never: [
        'Never cut the wound, suck it, or try to draw the venom out.',
        'Never apply a tight tourniquet. It costs limbs and does not help.',
        'Never apply ice, and never give alcohol or aspirin.',
        'Never chase the snake to identify it. A second bite is a real outcome.',
      ],
      callFor: 'Every snake bite and every mammal bite goes to hospital. Call '
          '1122 or 115 for an ambulance and start moving.',
      keywords: [
        'snake', 'snakebite', 'snake bite', 'bite', 'bitten', 'dog bite',
        'rabies', 'venom', 'scorpion', 'sting',
      ],
    ),

    // ---- Injury ----------------------------------------------------------
    SurvivalGuide(
      kind: Emergency.injury,
      icon: Icons.healing_rounded,
      firstThing: 'Make sure you are safe before you reach them — a second '
          'casualty helps nobody. Then: are they awake, and are they breathing?',
      steps: [
        GuideStep(
          'Not breathing',
          'Start chest compressions. Centre of the chest, hard and fast, about '
              'twice a second, and do not stop. Send someone else to call 1122. '
              'Compressions alone are worth doing even if you have never been '
              'trained.',
        ),
        GuideStep(
          'Heavy bleeding',
          'Press hard, directly on the wound, with anything — a cloth, a shirt, '
              'your hand. Keep pressing without lifting to look. Add more cloth '
              'on top rather than replacing it. Raise the limb if you can.',
        ),
        GuideStep(
          'A fall from height, or any hit to the head or back',
          'Do not move them unless they are in danger where they lie. Hold the '
              'head still in the position you found it, keep them warm and wait '
              'for help.',
        ),
        GuideStep(
          'A suspected broken bone',
          'Splint it in the position you found it, padded, tied above and below '
              'the break, never over it. Check the fingers or toes stay warm and '
              'pink afterwards; loosen at once if they do not.',
        ),
        GuideStep(
          'Burns',
          'Cool running water for twenty full minutes — this matters far more '
              'than anything applied afterwards. Then cover loosely with cling '
              'film or a clean cloth. Nothing greasy, no toothpaste, no ice.',
        ),
      ],
      never: [
        'Never move someone with a possible spine injury unless staying is more '
            'dangerous than moving.',
        'Never take a tight tourniquet off once someone has applied it — that '
            'is a hospital job.',
        'Do not give food or drink to anyone who may need surgery, or who is '
            'drowsy.',
      ],
      callFor: 'Call 1122, or 115 for an ambulance. On a highway, 130 will '
          'often reach you first.',
      note: 'This is what to do while help comes, not a substitute for it. A '
          'day\'s first aid course is the best thing any regular traveller can '
          'do before a trip.',
      keywords: [
        'injury', 'injured', 'hurt', 'bleeding', 'blood', 'broken', 'fracture',
        'fell', 'fall', 'accident', 'unconscious', 'burn', 'first aid', 'cpr',
      ],
    ),
  ];

  static SurvivalGuide forKind(Emergency kind) =>
      guides.firstWhere((g) => g.kind == kind);

  /// The guide a typed question is asking for, or null when nothing fits.
  ///
  /// Keyword-led rather than fuzzy-led: "fuel" must always reach the fuel guide
  /// and never a near-miss. The fuzzy pass only runs when no keyword hit, so a
  /// misspelling like "matchstik" still lands somewhere useful.
  static SurvivalGuide? match(String question) {
    final q = ' ${normalize(question)} ';
    if (q.trim().isEmpty) return null;

    SurvivalGuide? best;
    var bestScore = 0;

    for (final guide in guides) {
      var score = 0;
      for (final keyword in guide.keywords) {
        if (!q.contains(' ${normalize(keyword)} ')) continue;
        // A longer phrase matching is far stronger evidence than one short
        // word: "out of fuel" should beat a stray "fire" elsewhere in the
        // sentence.
        score += keyword.split(' ').length * 10 + keyword.length;
      }
      if (score > bestScore) {
        bestScore = score;
        best = guide;
      }
    }
    if (best != null) return best;

    // Nothing matched outright, so try for a misspelling — but only barely.
    //
    // Wrong guidance is worse than none here: answering "a beach trip" with
    // what to do in a landslide is nonsense on a good day and a waste of
    // minutes on a bad one, and that is exactly what the ordinary fuzzy
    // threshold did. So this pass only runs on a query short enough to be one
    // mistyped word, only against keywords long enough for a typo to be
    // recognisable, and only on a near-certain score.
    final tokens = normalize(question).split(' ').where((t) => t.isNotEmpty);
    if (tokens.length > 2) return null;

    for (final guide in guides) {
      final labels = guide.keywords.where((k) => k.length >= 6);
      if (labels.isEmpty) continue;
      if (scoreLabels(question, labels).score >= _typoThreshold) return guide;
    }
    return null;
  }

  /// Well above [fuzzyThreshold], which is tuned for place names where the user
  /// is definitely naming somewhere and only the spelling is in doubt.
  static const double _typoThreshold = 0.82;
}
