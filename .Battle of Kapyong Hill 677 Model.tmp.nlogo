extensions [csv]

globals [
  ; CSV data
  gradient-data
  elevation-data

  ; Multipliers (independent variables)
  ; Based on hill_multiplier
  steepness-multiplier
  weapons-multiplier

  ; Patch params
  meters-per-patch
  global-max-patch
  num-patches-x
  num-patches-y
  lat-min lat-max lon-min lon-max
  min-gradient max-gradient ; Track min/max gradients for scaling
  min-elevation max-elevation

  lat-range lon-range
  patch-lat-dim patch-lon-dim

  ; Turtle params
  initial-pva-troops
  initial-un-troops
  troops-per-agent
  max-energy

  un-initial-tiredness
  un-baseline-tiredness

  ; Custom colors
  dark-green
  light-green
  brownish-green
  light-brown
  dark-brown

  night?

  num_machguns
  num_morts

  reset-artillery-timers
  reset-mortar-timers
  last-barrage

  un-total-kills
  un-soldier-kills
  un-mortar-kills
  un-machgun-kills
  un-artilerly-kills
  pva-soldier-kills

  last-un-kills
  last-pva-kills
  un-kill-rate
  pva-kill-rate

  total-time
]

; Patch and turtle variables
patches-own [ gradient-value elevation-value orig-color]
turtles-own [movement-speed last-shot-time energy resting? tiredness]

; Custom breeds
breed [rings ring]  ;; Pulsing effect while resting


; ########################################################################################################################################
;                                                             PATCH DATA FUCNTIONS
; ########################################################################################################################################


to compute-patch-data-from-scratch
    ; Load elevation, gradient data
  ; Adjust resolution for map size
  (ifelse max-pxcor = 20 and max-pycor = 20[
    set gradient-data csv:from-file "./data/20x20/hill_677_gradient_data.csv"
    set elevation-data csv:from-file "./data/20x20/hill_677_elevation_data.csv"
    ]
    max-pxcor = 30 and max-pycor = 30[
      set gradient-data csv:from-file "./data/30x30/hill_677_gradient_data.csv"
      set elevation-data csv:from-file "./data/30x30/hill_677_elevation_data.csv"
    ]
    ; else
    [
      set gradient-data csv:from-file "./data/30x30/hill_677_gradient_data.csv"
      set elevation-data csv:from-file "./data/30x30/hill_677_elevation_data.csv"
  ])


  ; Remove headers
  set gradient-data but-first gradient-data
  set elevation-data but-first elevation-data

  ; Test data was loaded properly
  ; print "csv data"
  ;  print first gradient-data
  ;  print first elevation-data

  ; Aggregate the gradient data to the patch level (compute an average gradient per patch)
  ; Convert gradient lat/lon coords -> patch coords
  ; WORKING

  ask patches [
    ; Get coordinates for the current patch
    let patch-x-coord pxcor
    let patch-y-coord pycor
    let patch-threshold 5

    ; Find matching gradients that are within 0.5 of the current patch coordinates
    ; Normalizes lat/lon coordinates for gradients to lat=[min-pxcor, max-pxcor] and lon=[min-pycor, max-pycor]
    let matching-gradients filter [ [entry] ->
      (abs ((((item 0 entry - lat-min) / lat-range) * (max-pxcor - min-pxcor) + min-pxcor) - patch-x-coord) <= patch-threshold) and
      (abs ((((item 1 entry - lon-min) / lon-range) * (max-pycor - min-pycor) + min-pycor) - patch-y-coord) <= patch-threshold)
    ] gradient-data
    ;    print (word "matching-gradients length: " (length matching-gradients))  ; Debugging

    ; Compute average gradient for matching gradients
    if length matching-gradients > 0 [
      let avg-gradient mean map [ [gradient-entry] -> item 2 gradient-entry ] matching-gradients

      ; Update min/max gradient values
      if avg-gradient < min-gradient [
        set min-gradient avg-gradient
      ]
      if avg-gradient > max-gradient [
        set max-gradient avg-gradient
      ]

      ; Set the gradient value for the patch
      set gradient-value avg-gradient * steepness-multiplier ; hill_multiplier
      set plabel avg-gradient
      set plabel-color black
    ]



    let matching-elevations filter [ [entry] ->
      (abs ((((item 0 entry - lat-min) / lat-range) * (max-pxcor - min-pxcor) + min-pxcor) - patch-x-coord) <= patch-threshold) and
      (abs ((((item 1 entry - lon-min) / lon-range) * (max-pycor - min-pycor) + min-pycor) - patch-y-coord) <= patch-threshold)
    ] elevation-data

    ; Compute average elevation for matching elevations
    if length matching-elevations > 0 [
      let avg-elevation mean map [ [elevation-entry] -> item 2 elevation-entry ] matching-elevations

      if avg-elevation < min-elevation [
        set min-elevation avg-elevation
      ]
      if avg-elevation > max-elevation [
        set max-elevation avg-elevation
      ]

      ; Set the gradient value for the patch

      ; Store raw elevation in patch variable (not scaled)
      set elevation-value avg-elevation * steepness-multiplier ; hill_multiplier
    ]
  ]

  ; Export data to file
  export-patch-data
end

to export-patch-data
  let filename (word "./data/patch_data_" (max-pxcor * 2 + 1) "x" (max-pycor * 2 + 1) ".csv")
  carefully [file-delete filename] [print "creating new file"]
  file-open filename

  file-print "pxcor, pycor, elevation, gradient"
  ask patches [
    let line (word pxcor "," pycor "," elevation-value "," gradient-value)
;    print line
    file-print line
  ]

  file-close
end



; ENVIRONMENT SETUP/DATA PROCESSING
to import-patch-data
  let filename (word "./data/patch_data_" (max-pxcor * 2 + 1) "x" (max-pycor * 2 + 1) ".csv")
  file-open filename

  ; Skip the header line
  let first-line file-read-line

  while [not file-at-end?] [
    let line file-read-line
    let values csv:from-row line

    let px item 0 values
    let py item 1 values
    let elevation item 2 values
    let gradient item 3 values
;    print elevation
;    print gradient

     ; Update min/max elevation values
      if elevation < min-elevation [
        set min-elevation elevation
      ]
      if elevation > max-elevation [
        set max-elevation elevation
      ]

      ; Update min/max gradient values
      if gradient < min-gradient [
        set min-gradient gradient
      ]
      if gradient > max-gradient [
        set max-gradient gradient
      ]

    ask patch px py [
      set elevation-value (elevation * steepness-multiplier) ; * hill_multiplier
      set gradient-value (gradient * steepness-multiplier) ; * hill_multiplier
    ]
  ]

  file-close
  print "Patch data imported successfully!"
end


; ########################################################################################################################################
;                                                             ENV SETUP METHODS
; ########################################################################################################################################


to setup
  clear-all

;  ; Patch setup
;  set num-patches-x max-pxcor * 2 + 1 ; + 1 accounts for patch 00
;  set num-patches-y max-pycor * 2 + 1 ; + 1 accounts for patch 00


  ; Figure out whether we want to toggle hill steepness, weapon quantity, or both
  ifelse use-custom-sliders [
    set steepness-multiplier steepness
    set weapons-multiplier weapons
  ] [
    set steepness-multiplier hill_multiplier
    set weapons-multiplier hill_multiplier
  ]

  ; Set turtle params
  set initial-pva-troops 2000
  set initial-un-troops 100
  set troops-per-agent 5
  set max-energy 100
  set last-barrage 0

  ; UN tiredness stuff
  ; tiredness lies in range [un-baseline-tiredness, 100]
  set un-baseline-tiredness 10 ; never go below this level of tiredness
  set un-initial-tiredness 10 + 90 * (0.6 * steepness-multiplier + 0.4 * weapons-multiplier) ; steepness contributes 60%, weapons 40%
  ask turtles with [color = "white"] [
    ; initialize tiredness values for UN troops
    set tiredness un-initial-tiredness
  ]

  ; Set custom colors
  set light-green 66
  set dark-green 64
  set brownish-green 36
  set light-brown 35
  set dark-brown 32

  set night? True

  ; Meters per patch
  set meters-per-patch 18.15 ; 9.03

  ; Initialize min and max gradient values
  set min-gradient 999999
  set max-gradient -999999
  set min-elevation 999999
  set max-elevation -999999

  ; From hill_677_elevation_data:
  set lat-min 37.87275855821296
  set lat-max 37.89375855821291
  set lon-min 127.4644423642252
  set lon-max 127.49544236422535

  ; Calculate lat/lon range of model
  set lat-range (lat-max - lat-min)
  set lon-range (lon-max - lon-min)
  ;  print "lat/lon range:"
  ;  print lat-range
  ;  print lon-range

  set un-total-kills 0
  set un-mortar-kills 0
  set un-machgun-kills 0
  set un-soldier-kills 0
  set un-artilerly-kills 0
  set pva-soldier-kills 0

  ; Import patch data from pre-saved file
  carefully [import-patch-data] [print "Environment must be 201x201 patches"]

  ; OR uncomment below function calls to compute from scratch from raw elevation/gradient data:
;  compute-patch-data-from-scratch
;  export-patch-data

  ; Color patches based on elevation
  color-patches-with-elevation
  ; color-patches-with-gradient ; or with gradient instead

  spawn-forces



;  ; Remove patch labels (uncomment this to display gradient labels on view)
;  ask patches [
;  ;ifelse pxcor mod 3 = 0 and pycor mod 3 = 0 [  ;; Show label every 10 patches
;  ;  set plabel precision elevation-value 2
;  ;  set plabel-color black
;  ;] [
;    set plabel ""  ;; Hide label on other patches
;  ;]
;]

  reset-ticks
end





to spawn-forces
  clear-turtles

  ; SPAWN CHINESE (PVA) FIRST
  let cluster-radius-pva 20 ;; Controls spread of each cluster
  let cluster-size-pva initial-pva-troops / 9 / troops-per-agent
  let offset (cluster-radius-pva / 2)

  set global-max-patch max-one-of patches [elevation-value]
  let max-x [pxcor] of global-max-patch ; steepest point
  let max-y [pycor] of global-max-patch ; steepest point

  ;; Clump 1: Top Left
   create-turtles cluster-size-pva [
     setxy (min-pxcor + offset + random-float cluster-radius-pva - cluster-radius-pva / 2)
           (max-pycor - offset + random-float cluster-radius-pva - cluster-radius-pva / 2)
     set shape "person"
     set color black
;    pen-down
   ]

  ;; Clump 2: Top Middle
   create-turtles cluster-size-pva [
     setxy (0 + random-float cluster-radius-pva - cluster-radius-pva / 2)
           (max-pycor - offset + random-float cluster-radius-pva - cluster-radius-pva / 2)
     set shape "person"
     set color black
;    pen-down
   ]

  ;; Clump 3: Bottom Left
  create-turtles cluster-size-pva [
    setxy (min-pxcor + offset + random-float cluster-radius-pva - cluster-radius-pva / 2)
          (min-pycor + offset + random-float cluster-radius-pva - cluster-radius-pva / 2)
    set shape "person"
    set color black
    ;;pen-down
  ]

  ;; Clump 4: Middle Left
   create-turtles cluster-size-pva [
     setxy (min-pxcor + offset + random-float cluster-radius-pva - cluster-radius-pva / 2)
           (0 + random-float cluster-radius-pva - cluster-radius-pva / 2)
     set shape "person"
     set color black
     ;;pen-down
   ]

  ;; Clump 5: Between Top Left and Top Middle
  create-turtles cluster-size-pva [
    setxy ((min-pxcor + offset) / 2 + random-float cluster-radius-pva - cluster-radius-pva / 2)
    (max-pycor - offset + random-float cluster-radius-pva - cluster-radius-pva / 2)
    set shape "person"
    set color black
    ;;pen-down
  ]

;  ;; Clump 6: Between Middle Left and Top Middle
;   create-turtles cluster-size-pva [
;     setxy ((min-pxcor + offset) / 2 + random-float cluster-radius-pva - cluster-radius-pva / 2)
;     ((max-pycor - offset) / 2 + random-float cluster-radius-pva - cluster-radius-pva / 2)
;     set shape "person"
;     set color black
;    ;;pen-down
;   ]

  ;; Clump 7: Under Top Left
   create-turtles cluster-size-pva [
     setxy (min-pxcor + offset + random-float cluster-radius-pva - cluster-radius-pva / 2)
     ((max-pycor - offset) / 2 + random-float cluster-radius-pva - cluster-radius-pva / 2)
     set shape "person"
     set color black
    ;;pen-down
   ]

;  ;; Clump 8: Between Bottom Left and Middle Left
;   create-turtles cluster-size-pva [
;     setxy ((min-pxcor + offset) / 2 + random-float cluster-radius-pva - cluster-radius-pva / 2)
;     ((min-pycor + offset) / 2 + random-float cluster-radius-pva - cluster-radius-pva / 2)
;     set shape "person"
;     set color black
;    ;;pen-down
;   ]

  ;; Clump 9: Between Middle Left and Bottom Middle
   create-turtles cluster-size-pva [
     setxy (min-pxcor + offset + random-float cluster-radius-pva - cluster-radius-pva / 2)
     ((min-pycor + offset) / 2 + random-float cluster-radius-pva - cluster-radius-pva / 2)
     set shape "person"
     set color black
    ;;pen-down
   ]

  ;; Clump 10: Between Bottom Left and Bottom Middle
  create-turtles cluster-size-pva [
    setxy ((min-pxcor + offset) / 2 + random-float cluster-radius-pva - cluster-radius-pva / 2)
    (min-pycor + offset + random-float cluster-radius-pva - cluster-radius-pva / 2)
    set shape "person"
    set color black
    ;;pen-down
  ]

  ;; Clump 11: Bottom Middle
   create-turtles cluster-size-pva [
     setxy (0 + random-float cluster-radius-pva - cluster-radius-pva / 2)
     (min-pycor + offset + random-float cluster-radius-pva - cluster-radius-pva / 2)
     set shape "person"
     set color black
    ;;pen-down
   ]


  ; SPAWN UN FORCES
  let cluster-radius-un 15 ;; Controls spread of each cluster
  let cluster-size-un initial-un-troops / troops-per-agent ;; initial-un-troops (2 PPCLI D Company)

  ; CREATE UN WEAPONRY (SCALE QUANTITY BASED ON HILL STEEPNESS)
  ; Logistic growth (scaling) parameters
  let init_morts 3
  let init_machguns 2
  let max_factor 4
  let max_morts max_factor * init_morts
  let max_machguns max_factor * init_machguns
  let k 2.5  ;; Growth rate parameter

  ifelse use-custom-sliders = False [
    ; Logistic relationship when using hill_multiplier
    let exp-part exp (- k * ((1 / weapons-multiplier) - 1)) ; weapons-multipllier = hill_multiplier is x-axis (want growth to increase as it decreases)
    set num_morts int(max_morts / (1 + ((max_morts / init_morts) - 1) * exp-part))
    set num_machguns int(max_machguns / (1 + ((max_machguns / init_machguns) - 1) * exp-part))
  ] [
    ; Linear relationship for manual toggling
;    set num_morts int((max_factor - 1) * weapons-multiplier + init_morts)
;    set num_machguns int((max_factor - 1) * weapons-multiplier + init_morts)
    set num_morts int((max_morts - init_morts) * weapons-multiplier + init_morts)
    set num_machguns int((max_machguns - init_machguns) * weapons-multiplier + init_machguns)
  ]

  ; Machine guns (default 2)
  create-turtles num_machguns [
    setxy (max-x + random-float cluster-radius-un - cluster-radius-un / 2)
          (max-y + random-float cluster-radius-un - cluster-radius-un / 2)
    set shape "machine-gun"
    set size 10
    set color grey
    pen-down
  ]

  ; Mortars (default 3)
  create-turtles num_morts [
    setxy (max-x + random-float cluster-radius-un - cluster-radius-un / 2)
          (max-y + random-float cluster-radius-un - cluster-radius-un / 2)
    set shape "mortar"
    set size 10
    set color grey
    pen-down
  ]

  ; Troops
;  create-turtles (cluster-size-un - num_machguns * (ceiling (3 / troops-per-agent)) - num_morts * ceiling ((3 / troops-per-agent))) [ ; min 3 troops per machine gun, min 3 per mortar

  ; Consistent number of troops each time (regardless of machine gun/mortar crews)
  create-turtles cluster-size-un [
    setxy (max-x + random-float cluster-radius-un - cluster-radius-un / 2)
          (max-y + random-float cluster-radius-un - cluster-radius-un / 2)
    set shape "person"
    set color white  ;; Color different for visibility (optional)
    set last-shot-time 0
    set energy 100 ; max energy
    set resting? false

    pen-down
  ]
end

to color-patches-with-elevation
  ; Color patches based on the their elevation value
  ask patches [
    if elevation-value != 0 [
      ; Brown scale
      ; set pcolor scale-color brown plabel min-gradient max-gradient

      ; Green -> Brown scale
      let norm-elevation ((elevation-value - min-elevation) / (max-elevation - min-elevation)) / steepness-multiplier ; normalize elevation between [0, 1]

      ifelse night? [
        ; NIGHT COLORS
        if norm-elevation < 0.1 [ set pcolor 75.4 ]  ; Flat grass
        if norm-elevation >= 0.1 and norm-elevation < 0.4 [ set pcolor 83.5 ]  ; Light hills
        if norm-elevation >= 0.4 and norm-elevation < 0.6 [ set pcolor 103.5 ]  ; Medium terrain
        if norm-elevation >= 0.6 and norm-elevation < 0.8 [ set pcolor 33 ]  ;; Steeper terrain
        if norm-elevation >= 0.8 [ set pcolor dark-brown ]  ;; Very steep terrain/rocky cliffs
      ]
      [
        ; Assign color based on thresholded ranges
        ; DAY COLORS
        if norm-elevation < 0.1 [ set pcolor light-green ]  ; Flat grass
        if norm-elevation >= 0.1 and norm-elevation < 0.4 [ set pcolor dark-green ]  ; Light hills
        if norm-elevation >= 0.4 and norm-elevation < 0.6 [ set pcolor brownish-green ]  ; Medium terrain
        if norm-elevation >= 0.6 and norm-elevation < 0.8 [ set pcolor light-brown ]  ;; Steeper terrain
        if norm-elevation >= 0.8 [ set pcolor dark-brown ]  ;; Very steep terrain/rocky cliffs
      ]
    ]

    ; Set patches with no elevation data to grey
    if elevation-value = 0
    [
      set pcolor grey
    ]
  ]
end

to color-patches-with-gradient
  ; Color patches based on the their gradient value
  ask patches [
    if gradient-value != 0 [
      ; Brown scale
      ; set pcolor scale-color brown plabel min-gradient max-gradient

      ; Green -> Brown scale
      let norm-gradient (gradient-value - min-gradient) / (max-gradient - min-gradient) ; normalize gradient between [0, 1]

      ; Assign color based on thresholded ranges
      if norm-gradient < 0.1 [ set pcolor light-green ]  ; Flat grass
      if norm-gradient >= 0.1 and norm-gradient < 0.4 [ set pcolor dark-green ]  ; Light hills
      if norm-gradient >= 0.4 and norm-gradient < 0.6 [ set pcolor brownish-green ]  ; Medium terrain
      if norm-gradient >= 0.6 and norm-gradient < 0.8 [ set pcolor light-brown ]  ;; Steeper terrain
      if norm-gradient >= 0.8 [ set pcolor dark-brown ]  ;; Very steep terrain/rocky cliffs
    ]

    ; Set patches with no elevation data to grey
    if gradient-value = 0
    [
      set pcolor grey
    ]
  ]
end





; ########################################################################################################################################
;                                                             AGENTS SHOOTING INTERACTIONS
; ########################################################################################################################################


to un-turtle-shoot-at-pva-turtle [tiredness-multiplier]
  let shooting-range 100  ;; Maximum shooting distance
  let effectiveness 1.22 ; lower is worse
  let fire-rate calculate-fire-rate 4 1 20 ; k min-rate max-rate

  if (ticks - last-shot-time >=  fire-rate * 5 - random (5)) [
    set last-shot-time ticks
    let target min-one-of turtles with [color = black] [distance self]
    if target != nobody and [distance target] of self <= shooting-range [
      let prob compute-hit-probability-for-un self target effectiveness 30 hill_cover ;; params: shooter, target, bullet_effectiveness, bullet_range, cover_factor

      ; Account for tiredness
;       print tiredness-multiplier
;      print prob
      set prob un-hit-probability-with-tiredness prob tiredness-multiplier
;      print prob
      if random-float 1 < prob and prob > 0.001 [
        set un-soldier-kills un-soldier-kills + 1
        ask target [ die ] ;; Kill black agent if hit
      ]
    ]
  ]
end


to pva-turtle-shoot-at-un-turtle [energy-multiplier]
  let shooting-range 100  ;; Maximum shooting distance
  let effectiveness 1.1 ; slightly less effective than UN
  let fire-rate calculate-fire-rate 4 1 35 ; k min-rate max-rate

  if (ticks -  last-shot-time >=  fire-rate * 5 - random (5)) [
    set last-shot-time ticks
    let target min-one-of turtles with [color = white] [distance self]
    if target != nobody and [distance target] of self <= shooting-range [
      let prob compute-hit-probability-for-pva self target effectiveness 20 ;; params: shooter, target, bullet_effectiveness, bullet_range

    ;; Account for energy level
    set prob (prob * energy-multiplier)

    if random-float 1 < prob and prob > 0.001 [
      ;; print "white died"
      ;; print prob
      ;; print [distance target] of self
      ;; print ([elevation-value] of target - [elevation-value] of self) / ([distance target] of self * meters-per-patch)
      set pva-soldier-kills pva-soldier-kills + 1
      ask target [ die ]  ;; Kill white agent if hit
    ]
    ]
  ]
end


; SHOOTING PROBABILITIES
to-report compute-hit-probability-for-pva [shooter target bullet_effectiveness bullet_range]
  let dist [distance target] of shooter
  let shooter-elevation [elevation-value] of shooter
  let target-elevation [elevation-value] of target
  let grad (target-elevation - shooter-elevation) / (dist * meters-per-patch)

  let theta (- grad) ; invert so that shooting UPHILL is a DISADVANTAGE
  let s (tanh theta)

  let r-theta (4 - ((theta * 100) / 15)) ^ 2
  let R bullet_effectiveness
  let D bullet_range
  let hit-probability-at-25 (exp (-1 * R / (-1 * r-theta))) * exp ((-1 * dist) / D)

  let hit-probability 0
  ifelse dist <= bullet_range [
    set hit-probability 1 - (1 - hit-probability-at-25) * exp (-5 * (bullet_range - dist) / bullet_range)
  ] [
    set hit-probability (1 - exp (-1 * R / (-1 * r-theta)) * exp ((-1 * dist) / D)
  ]
  if hit-probability > 0.001 [
    print r-theta
  ]
  report hit-probability
end

to-report compute-hit-probability-for-un [shooter target bullet_effectiveness bullet_range cover_factor]
  let dist [distance target] of shooter
  let shooter-elevation [elevation-value] of shooter
  let target-elevation [elevation-value] of target
  let grad (target-elevation - shooter-elevation) / (dist * meters-per-patch)

  let theta (- grad) ; invert so that shooting DOWNHILL is an ADVANTAGE
  let s (tanh theta)

  let r-theta (4 - ((theta * 100) / 15)) ^ 2
  let R bullet_effectiveness
  let D bullet_range
  let hit-probability (1 - exp (-1 * R / r-theta)) * exp ((-1 * dist) / D) / 2


  ; Multiply entire prob by cover factor
  set hit-probability hit-probability * (1 - 0.5 * cover_factor)

  report hit-probability
end

to-report tanh [x]
  set x x * 100 * pi / 180
  report (exp x - exp (-1 * x)) / (exp x + exp (-1 * x))
end


to-report calculate-fire-rate [k min_rate max_rate]
  let min_hill 0.01
  let max_hill 1.25

  let normalized_hill (steepness-multiplier - min_hill) / (max_hill - min_hill)
  let fire_rate min_rate + (max_rate - min_rate) * (1 - normalized_hill ^ k)
  report fire_rate  ; Returns the calculated fire rate
end

to-report un-hit-probability-with-tiredness [base-prob tiredness-multiplier]
  ; exponential decay (stronger impact on prob with higher tiredness)
  ; tiredness = 0.1 (well rested) -> 1 (no penalty)
  ; tiredness = 0.5 (decently rested) -> 0.67 (33% penalty)
  ; tiredness = 1.0 (completely exhausted) -> 0.41 (59% penalty)

  let base-tiredness un-baseline-tiredness / 100
;  print(exp(baseline-tiredness - tiredness-multiplier))
  report base-prob * exp(base-tiredness - tiredness-multiplier)
end


; ########################################################################################################################################
;                                                             GO METHOD
; ########################################################################################################################################

to go
  reset-artillery-colors
  reset-mortar-colors

  ; Log metrics
  set total-time (ticks * 5) / 3600
  set un-total-kills un-soldier-kills + un-artilerly-kills + un-machgun-kills + un-mortar-kills

  if ticks != 0 and ticks mod (3600 / 5) = 0 [
  ; record kill rate per hour
    set un-kill-rate un-total-kills - last-un-kills
    set pva-kill-rate pva-soldier-kills - last-pva-kills
    set last-un-kills un-total-kills
    set last-pva-kills pva-soldier-kills
  ]

  check-end-conditions

  ;; STEPS PER TICK
  ;; 1. Perform artillery strikes
  ;; 2. Agents shoot
  ;; 3. Weapons shoot
  ;; 4. Agents (PVA) move
  ;; 5. Check end conditions

  ; Artillery strike
  if ticks mod 6 * 5 = 0 [  ; Conduct a strike every 12 ticks (once per minute)
    perform-artillery-strike
  ]

  ; Mortar fire
  if ticks mod 12 * 5 = 0 [
    ask turtles with [shape = "mortar"] [
      perform-mortar-strike
    ]
  ]

  ; Machine gun fire
  if ticks mod  5 = 0 [
    ask turtles with [shape = "machine-gun"] [
      fire-machine-gun
    ]
  ]

  ; Artillery barrage
  ; Only fires if UN troops begin to get overrun
  if last-barrage = 0 or (ticks - last-barrage > 3600 / 5) [ ; max one barrage per hour
      perform-artillery-barrage
  ]

  ; UN turtles
  ask turtles with [color = white] [
    ; Update tiredness
    let tiredness-multiplier update-un-tiredness self
;    print tiredness-multiplier

;    ; Check if resting
;    ifelse resting? = true [
;      rest
;    ]
;    [
;      ; Deplete energy and get energy multiplier (energy / max-energy)
;      let energy-multiplier deplete-energy self

      ; Shoot
      if ticks mod 5 = 0 [
        un-turtle-shoot-at-pva-turtle tiredness-multiplier
      ]

      ; Close quarters combat: throw grenades or bayonet rush
       if ticks mod 5 = 0 [
         perform-grenade-bayonet tiredness-multiplier
       ]
;    ]
  ]

  ; PVA turtles
  ask turtles with [color = black][
    ; Check if resting
    ifelse resting? = true [
      rest
    ]
    [
      ; Deplete energy and get energy multiplier (energy / max-energy)
      let energy-multiplier deplete-energy self

      ; Shoot
      pva-turtle-shoot-at-un-turtle energy-multiplier

      ; Move
      let current-patch patch-here
      let current-elevation [elevation-value] of current-patch
      let current-target patch-here

      ;; Step 1: Identify the global maximum elevation patch
      let closest-white-turtle min-one-of turtles with [color = white] [distance myself]
      let target-patch 0
      ifelse closest-white-turtle = nobody [
        stop
        ; set target-patch max-one-of patches [elevation-value]
      ] [
        set target-patch [patch-here] of closest-white-turtle
      ]

      ifelse target-patch != nobody [


        if patch-here = closest-white-turtle [
          stop
        ]

        ;; Step 2: Find neighboring patches
        let candidate-patches neighbors

        let speed-scale 10



        let min-cost 999999999
        let second-min-cost 999999999
        let best-patch nobody
        let second-best-patch nobody

        foreach (sort neighbors) [neighbor ->
          if ([pxcor] of neighbor > min-pxcor and [pxcor] of neighbor < max-pxcor and
            [pycor] of neighbor > min-pycor and [pycor] of neighbor < max-pycor) [

            ;; Calculate terrain movement cost using Tobler’s cost function
            let terrain-cost -1 * (6 * exp (-3.5 * abs tan ([gradient-value] of neighbor * 100)))

            ;; Compute average elevation of neighboring patches
            let avg-neighbor-elevation mean [elevation-value] of neighbors

            ;; Calculate elevation difference from the average
            let elevation-diff abs([elevation-value] of neighbor - avg-neighbor-elevation)

            ;; Apply ridge penalty if the elevation difference is significant
            let ridge-penalty max (list 0 (30 * ([1 - gradient-value] of neighbor ^ 2)))

            let dist-to-target 2 * sqrt (([pxcor] of neighbor - [pxcor] of target-patch) ^ 2 +
              ([pycor] of neighbor - [pycor] of target-patch) ^ 2)

            let elevation-diff-to-target [elevation-value] of target-patch - [elevation-value] of neighbor
            let elevation-bonus ifelse-value (elevation-diff-to-target > 0) [-1 * elevation-diff-to-target * 2] [0]  ;; Reward uphill movement
            set elevation-bonus 0

            ;; Compute total movement cost
            let total-cost terrain-cost + ridge-penalty + dist-to-target + elevation-bonus

            ;; Update best and second-best patches
            ifelse (total-cost < min-cost) [
              set second-min-cost min-cost
              set second-best-patch best-patch
              set min-cost total-cost
              set best-patch neighbor
            ]
            [ ;; The else block for ifelse (must be a valid command block)
              if (total-cost < second-min-cost) [
                set second-min-cost total-cost
                set second-best-patch neighbor
              ]
            ]
          ]
        ]

        ;; Randomly choose between the two best patches
        if second-best-patch != nobody and random 2 = 0 and (min-cost / second-min-cost) > 0.7[
          set best-patch second-best-patch
        ]

        ;; Move toward the best patch if it's valid
        if best-patch != nobody [
          face best-patch

          ;; Compute movement speed dynamically based on chosen patch
          set movement-speed (0.371 * exp (-3.5 * abs tan ([gradient-value] of best-patch * 100) + 0.05))  ;; Tobler’s formula
          let real-speed (movement-speed * 18 / 5) * 3.6
          ;; print (word "Current speed: " real-speed)

          ; Move
          fd movement-speed * energy-multiplier
        ]
      ] [
        ; Do nothing
        ; stop
      ]
    ]
  ]

;  fade-rings
  tick
end

to check-end-conditions

  let initial-pva-count initial-pva-troops / troops-per-agent
  let remaining-pva count turtles with [color = black]
  let remaining-un count turtles with [color = white]

  if (remaining-pva < 0.1 * initial-pva-count) [
;    print(initial-pva-count)
;    print(remaining-pva)
;    print(0.1 * initial-pva-count)
;    print(initial-pva-troops)
;    print(un-total-kills * troops-per-agent)
    display ; update plots
    user-message "The UN wins! The PVA has surrendered."
    stop
  ]

  if (remaining-un = 0) [
    display ; update plots
    user-message "The PVA wins! All UN troops have been eliminated."
    stop
  ]
end


; ########################################################################################################################################
;                                                             Energy/Resting Methods
; ########################################################################################################################################


to-report deplete-energy [soldier]
  let slope [gradient-value] of soldier
  let normalized-slope max (list (slope / max-gradient) 0.3)
  let k 1.1                       ;; Energy loss per slope unit (steepness)
  let m 0.015                       ;; Base energy loss per tick (flat ground)

  ;; Compute new energy level
  ask soldier [
    set energy energy - (k * normalized-slope) - m

    ;; Rest if energy < 20% (75% chance)
    if energy < 20 and random-float 1.0 < 0.75 [
      set resting? true
    ]

    ;; If energy is completely depleted, must rest
    if energy < 0 [
      set resting? true
      set energy 0
    ]
  ]

  ;; Return energy percentage as a multiplier
  report ([energy] of soldier) / max-energy
end


to rest
  ; Show yellow ring while resting
;  pulse-ring

  let r 12 ;; Recovery rate per tick
  set energy (energy + r)

  ;; Stop resting when recovered to > 40% energy (25% chance)
  if energy > 40 and random-float 1.0 < 0.25 [
    set resting? false
  ]
end


; Movement visuals
to pulse-ring
  hatch-rings 1 [
    set size 2.5
    set color yellow
    set shape "circle 2"
  ]
end

to fade-rings
  ask rings [
    set size size + 1
;    set color color - 5  ;; Gradually fade color (reduce brightness)
    if size > 6 [ die ]  ;; Remove ring after expanding
  ]
end


to-report update-un-tiredness [soldier]
  let un-tiredness-multiplier 0

  ask soldier [
    ; logistic decay function (tiredness initially decreases at a slow rate, then at a faster rate, and then slows back down)
    ; tiredness lies in range [un-baseline-tiredness, 100]
    let decay-rate 0.005 - 0.004 * (0.6 * steepness-multiplier + 0.4 * weapons-multiplier) ; steepness contributes 60%, weapons 40%
    let t0 600  ; midpoint where rate is highest (tiredness decreases fastest)

    ; update tiredness
    set tiredness un-baseline-tiredness + (un-initial-tiredness - un-baseline-tiredness) / (1 + exp(- decay-rate * (ticks - t0)))
    set un-tiredness-multiplier tiredness / 100
  ]

  report un-tiredness-multiplier ; return UN tiredness as a percentage
end

; ########################################################################################################################################
;                                                             Artillery Method
; ########################################################################################################################################


; GENERAL ARTILLERY STRIKE
to perform-artillery-strike
  let target max-one-of patches [count turtles-here with [color = black]]
  let noisy-x ( [pxcor] of target ) + random-normal 2 1
  let noisy-y ( [pycor] of target ) + random-normal 2 1
  let noisy-patch patch round noisy-x round noisy-y

  ask noisy-patch [




    let immediate-death-zone turtles-here
    let near-zone turtles in-radius 2

    let sure-deaths 0
    ask immediate-death-zone [
      if random-float 1.0 < 0.5 [  ; 90% chance to die
        set un-artilerly-kills un-artilerly-kills + 1
        die

      ]
    ]
    ; print (word "Total turtles immediately killed: " sure-deaths)

    ; Calculate and execute probabilistic effects in the surrounding area TODO
    let near-deaths 0
      ask near-zone [
        if random-float 1.0 < 0.1 [  ; 30% chance to die
          set near-deaths near-deaths + 1
          die
        ]
      ]
      ; print (word "Total turtles killed in the near zone: " near-deaths)



    ask patches in-radius 2 [
      if pcolor != red [ ; avoid coloring permanently
        set orig-color pcolor
        set pcolor red
      ]
    ]

    set reset-artillery-timers 3

  ]

end

; ARTILLERY BARRAGE
to perform-artillery-barrage
  ;; Get the patches within a radius of 15 from the UN troops
  let un-x [pxcor] of global-max-patch
  let un-y [pycor] of global-max-patch
  let center-patches patches with [distancexy un-x un-y <= 15]

  ;; Count total troops and PVA troops in the center area
  let total-troops count turtles with [member? patch-here center-patches]
  let pva-troops count turtles with [color = black and member? patch-here center-patches]

  ;; Check if PVA troops make up ≥ 50%
  if (total-troops > 0 and (pva-troops / total-troops) >= 0.5) [
    print("Artillery barrage!")
    set last-barrage ticks

    ;; Call artillery strike on center patches
    ; Do 5 mini waves of strikes
    repeat 5 [
      ; Sample random patches within strike zone (with replacement)
      let strike-patches n-of 350 center-patches
      ask strike-patches [
        let pva-zone turtles-here with [color = black]  ;; PVA troops
        let un-zone turtles-here with [color = white]    ;; UN troops

        ;; 90% chance to die for PVA
        ask pva-zone [
          if random-float 1.0 < 0.9 [
            print "pva killed from barrage"
            set un-artilerly-kills un-artilerly-kills + 1
            die
          ]
        ]

        ;; 0.1% chance to die for UN
        ask un-zone [
          if random-float 1.0 < 0.001 [
;            print "un killed from barrage"
            die
          ]
        ]

        ;; Visual effect: Change patch color to red
        if pcolor != red [ ; avoid coloring permanently
          set orig-color pcolor
          set pcolor red
        ]
      ]

      ;; Reset the red effect after 3 ticks
      set reset-artillery-timers 3

;    ; Remove sampled patches from pool
;    set center-patches center-patches with [not member? self strike-patches]
    ]
  ]
end


to reset-artillery-colors
  if reset-artillery-timers >= 0 [
    set reset-artillery-timers reset-artillery-timers - 1
    if reset-artillery-timers = 0 [
      ask patches with [pcolor = red] [  ; Only reset patches that are currently red
        set pcolor orig-color  ; Restore the original color
      ]
    ]
  ]
end



; ########################################################################################################################################
;                                                             Mortars/Machine Guns Method
; ########################################################################################################################################



; M2 60mm mortars: https://en.wikipedia.org/wiki/M2_mortar#:~:text=The%20M2%20mortar%20is%20a,War%20for%20light%20infantry%20support.
; 18 rounds per minute (1 min = 12 ticks)
; range (meters): [180, 1844]
to perform-mortar-strike
  let target nobody

  ;; Define the minimum and maximum range in patches
  let min-range 20  ;; Corresponding to 180 meters (88 m. per patch)
  let max-range 55  ;; Corresponding to 1844 meters

  ;; Find the patch with the highest concentration of PVA troops within range of the firing mortar
  set target max-one-of patches in-radius max-range [count turtles-here with [color = black]]

  ;; Make sure target isn't too close
  if (abs [pxcor] of target <= min-range) and (abs [pycor] of target <= min-range) [
    set target nobody
  ]

  if target != nobody [
    ;; Add some noise to the strike (mimic inaccuracy)
    let noisy-x ( [pxcor] of target ) + random-normal 2 1
    let noisy-y ( [pycor] of target ) + random-normal 2 1
    let noisy-patch patch round noisy-x round noisy-y

    ;; Perform the mortar strike on the chosen patch
    let nums 0
    ask noisy-patch [
      set nums count turtles in-radius 2 with [color = black]
    ]
    if nums > 0 [
      ask noisy-patch [
        ;; Define the impact zones (immediate-death-zone and near-zone)
        let immediate-death-zone turtles-here with [color = black]
        let near-zone turtles in-radius 2 with [color = black]

        ;; Immediate death chance for black troops
        ask immediate-death-zone [
          if random-float 1.0 < 0.3 [
            set un-mortar-kills un-mortar-kills + 1
            die
          ]
        ]

        ;; Mortar effect on nearby black troops
        let near-deaths 0
        ask near-zone [
          if random-float 1.0 < 0.05 [
            set near-deaths near-deaths + 1
            set un-mortar-kills un-mortar-kills + 1
            die
          ]
        ]

        ;; Visual effect: Change the color of affected patches
        ask patches in-radius 2 [
          if pcolor != yellow [ ; avoid coloring permanently
            set orig-color pcolor
            set pcolor yellow
          ]
        ]

        ;; Reset the timers for the yellow effect
        set reset-mortar-timers 2
      ]
    ]
  ]
end

; Vickers machine guns: https://en.wikipedia.org/wiki/Vickers_machine_gun
; 450 rounds per min (per 12 ticks)
; 2000 meter range (111 patches)
to fire-machine-gun
  let shooting-range 60  ;; Maximum shooting distance
  let num-shots 48  ;; Max fire rate (per tick)
  let effectiveness 0.5 ; lower is worse

  let fire-rate calculate-fire-rate 4 (num-shots / 2) num-shots ; k min-rate max-rate

  ;; Fire num-shots times per tick
  repeat fire-rate [
    let target min-one-of turtles with [color = black] [distance self]
    if target != nobody and [distance target] of self <= shooting-range [
      let prob compute-hit-probability-for-un self target effectiveness shooting-range hill_cover ;; params: shooter, target, bullet_effectiveness, bullet_range, cover_factor

      if random-float 1 < prob and prob > 0.001 [
        set un-machgun-kills un-machgun-kills + 1
        ask target [ die ] ;; Kill black agent if hit
      ]
    ]
  ]
end

to reset-mortar-colors
  if reset-mortar-timers >= 0 [
    set reset-mortar-timers reset-mortar-timers - 1
    if reset-mortar-timers = 0 [
      ask patches with [pcolor = yellow] [  ; Only reset patches that are currently yellow
        set pcolor orig-color  ; Restore the original color
      ]
    ]
  ]
end



; ########################################################################################################################################
;                                                             Close Quarters Combat: Grenades & Bayonet
; ########################################################################################################################################
to perform-grenade-bayonet [tiredness-multiplier]
  let close-range 0.5  ;; We'll say grenade/bayonet is effective when they're in the same patch

  ;; Find all nearby turtles within the close-range threshold
  let nearby-turtles turtles in-radius close-range

  ask nearby-turtles [
    if color = black [  ;; If enemy is a PVA soldier
      let prob random-float 1.0
      set prob un-hit-probability-with-tiredness prob tiredness-multiplier
      if prob < 0.4 [  ;; fairly high chance PVA soldier dies (lower accounting for tiredness)
;        print("grenade/bayonet!")
        set un-soldier-kills un-soldier-kills + 1
        die
      ]
    ]
  ]
end
@#$#@#$#@
GRAPHICS-WINDOW
253
47
763
558
-1
-1
2.5
1
10
1
1
1
0
1
1
1
-100
100
-100
100
0
0
1
ticks
30.0

BUTTON
40
62
106
95
NIL
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
124
62
187
95
NIL
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
0

BUTTON
50
105
177
138
respawn forces
spawn-forces
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
29
151
201
184
hill_multiplier
hill_multiplier
0.01
1.25
0.25
0.01
1
NIL
HORIZONTAL

TEXTBOX
775
288
956
331
E\n
24
15.0
1

TEXTBOX
499
10
665
40
N
24
15.0
1

TEXTBOX
502
568
668
624
S
24
15.0
1

TEXTBOX
217
288
372
337
W
24
15.0
1

PLOT
1210
45
1410
195
total un kills
ticks
kills
0.0
1000.0
0.0
2000.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot (un-total-kills * troops-per-agent)"

PLOT
1022
351
1182
471
un artillery kills
ticks
kills
0.0
1000.0
0.0
200.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot un-artilerly-kills * troops-per-agent"

PLOT
1212
498
1412
648
total pva kills
ticks
kills
0.0
1000.0
0.0
100.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot (pva-soldier-kills * troops-per-agent)"

SLIDER
29
197
201
230
hill_cover
hill_cover
0.0
1.0
0.05
0.01
1
NIL
HORIZONTAL

MONITOR
31
471
164
516
# UN machine guns
num_machguns
17
1
11

MONITOR
31
524
127
569
# UN mortars
num_morts
17
1
11

MONITOR
31
417
180
462
total sim. time (hours)
total-time
2
1
11

PLOT
1006
45
1195
195
un kill rate (troops/hr)
ticks
kill rate
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot un-kill-rate * troops-per-agent"

PLOT
999
498
1199
648
pva kill rate (troops/hr)
ticks
kill rate
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot pva-kill-rate * troops-per-agent"

PLOT
830
216
990
336
un soldier kills
ticks
kills
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot un-soldier-kills * troops-per-agent"

PLOT
1021
216
1181
336
un machine gun kills
ticks
kills
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot un-machgun-kills * troops-per-agent"

PLOT
1212
216
1372
336
un mortar kills
ticks
kills
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot un-mortar-kills * troops-per-agent"

TEXTBOX
797
472
947
491
PVA:
15
0.0
1

TEXTBOX
810
21
960
41
UN:
16
0.0
1

MONITOR
808
45
894
90
initial troops
initial-un-troops
17
1
11

MONITOR
796
498
879
543
initial troops
initial-pva-troops
17
1
11

MONITOR
899
45
994
90
remaining
initial-un-troops - (pva-soldier-kills * troops-per-agent)
17
1
11

MONITOR
888
498
988
543
remaining
initial-pva-troops - (un-total-kills * troops-per-agent)
17
1
11

MONITOR
813
101
990
146
current un kill rate (troops/hr)
un-kill-rate * troops-per-agent
17
1
11

MONITOR
800
552
985
597
current pva kill rate (troops/hr)
pva-kill-rate * troops-per-agent
17
1
11

MONITOR
31
578
148
623
troops per agent
troops-per-agent
17
1
11

SWITCH
27
264
207
297
use-custom-sliders
use-custom-sliders
1
1
-1000

SLIDER
30
306
202
339
steepness
steepness
0.01
1.0
1.0
0.01
1
NIL
HORIZONTAL

SLIDER
29
349
201
382
weapons
weapons
0
1
1.0
0.01
1
NIL
HORIZONTAL

@#$#@#$#@
## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

machine-gun
true
0
Rectangle -7500403 true true 144 0 159 105
Line -16777216 false 45 75 255 75
Line -16777216 false 45 60 255 60
Line -16777216 false 45 240 255 240
Line -16777216 false 45 225 255 225
Line -16777216 false 45 195 255 195
Line -16777216 false 45 150 255 150
Rectangle -16777216 false false 135 105 165 120
Rectangle -955883 false false 143 0 158 105
Rectangle -7500403 true true 105 105 195 255
Polygon -955883 false false 105 105 105 255 195 255 195 105 150 105 105 105 105 105

mortar
true
0
Polygon -7500403 true true 165 30 165 45 165 180 165 195 165 210 165 255 165 255 135 255 135 255 135 210 135 195 135 180 135 45 135 30
Line -16777216 false 120 150 180 150
Line -16777216 false 120 195 180 195
Line -16777216 false 165 30 135 30
Polygon -1184463 false false 165 30 135 30 135 45 135 180 135 195 135 210 135 225 135 255 165 255 165 225 165 210 165 195 165 180 165 45
Rectangle -7500403 true true 90 255 210 270
Polygon -7500403 false true 90 255
Rectangle -1184463 false false 90 255 210 270

mortar2
false
0
Polygon -7500403 true true 255 135 195 210 210 210 255 150 285 210 300 210 255 135 255 150
Rectangle -7500403 true true 30 195 120 210
Polygon -7500403 true true 120 165 120 165 75 180 75 195 255 135 255 120 75 180
Polygon -2674135 false false 75 180 75 195 255 135 255 120
Rectangle -7500403 true true 30 195 120 195
Rectangle -7500403 true true 120 195 120 210
Polygon -2674135 false false 75 195 30 195 30 210 120 210 120 195 75 195
Polygon -2674135 false false 255 135 195 210 210 210 255 150 285 210 300 210 255 135

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

rocket
true
0
Polygon -7500403 true true 120 165 75 285 135 255 165 255 225 285 180 165
Polygon -1 true false 135 285 105 135 105 105 120 45 135 15 150 0 165 15 180 45 195 105 195 135 165 285
Rectangle -7500403 true true 147 176 153 288
Polygon -7500403 true true 120 45 180 45 165 15 150 0 135 15
Line -7500403 true 105 105 135 120
Line -7500403 true 135 120 165 120
Line -7500403 true 165 120 195 105
Line -7500403 true 105 135 135 150
Line -7500403 true 135 150 165 150
Line -7500403 true 165 150 195 135

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.4.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
