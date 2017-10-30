breed [queens queen]
breed [larvae larva]
breed [workers worker]

queens-own [age energy poisoned destination]
larvae-own [age energy poisoned to-be-queen]
workers-own [age energy poisoned current-action carrying destination]
patches-own [honey-patch-uses]

to setup
  clear-all                           ;; clear the screen
  setup-world
  setup-food
  setup-worker
  setup-queen
  reset-ticks
end

to setup-world
  resize-world 0 hive-size 0 hive-size
  ask patches [set pcolor yellow]       ;; set the background (patches) to gray
  ask patches with [pxcor = 0] [set pcolor black]
  ask patches with [pxcor = hive-size] [set pcolor black]
  ask patches with [pycor = 0] [set pcolor black]
  ask patches with [pycor = hive-size] [set pcolor black]
end

to setup-queen
  create-queens 1
  ask queens
  [set color gray
    set age 5
    set poisoned false
    set energy max-energy-queen
    setxy hive-size / 2 hive-size / 2
    set shape "queen"
    set size 1.1
    set destination ""
  ]
end

to setup-worker
  create-workers number-of-workers
  ask workers
  [set color gray
    set age random max-age-worker
    set size 0.8
    set poisoned false
    set current-action ""
    set energy max-energy-worker
    set carrying ""
    set destination ""
    move-to one-of patches with [pcolor = yellow]
    set shape "worker"
  ]
end

to setup-food
  ;;food at the sides
  ask patches with [pxcor = 0 and pycor = hive-size / 2] [set pcolor blue]
  ask patches with [pxcor = hive-size and pycor = hive-size / 2] [set pcolor blue]
  ask patches with [pycor = 0 and pxcor = hive-size / 2] [set pcolor blue]
  ask patches with [pycor = hive-size and pxcor = hive-size / 2] [set pcolor blue]
  ask patches [set honey-patch-uses 0]
  ask n-of number-of-food-sources-poisoned patches with [pcolor = blue] [set pcolor green]
end

;;Main

to go
  if count turtles = 0
  [stop]
  let i 0
  while [i <= actions-per-day / ticks-per-day]
  [
    queen-action
    larvae-action
    worker-action
    set i (i + 1)
  ]
  ask turtles [set energy (energy - 1)]
  age-all
  death-check
  limit-energy
  tick
end

to queen-birth
  move-to patch-here ;;stops the larvae being off center.
  hatch-larvae 1 [set age 0 set energy max-energy-larvae set poisoned false set shape "larvae" set color white set to-be-queen false]
  set color gray
  set destination ""
end

to queen-action
  ask queens[
    if age > 5
    [

      let free-patches patches with [pcolor = yellow and not any? larvae-here]

      if poison-check = true[
        ;;if no free spaces don't attempt anything
        ifelse not any? free-patches
        [set destination ""]
        ;;Otherwise set destination to closest patch to middle of hive and to queen
        [set destination (min-one-of (free-patches with-min [distance patch (hive-size / 2) (hive-size / 2)]) [distance myself])]

        if destination != ""
        [move-to destination
          queen-birth]]
    ]
   ]
end

to larvae-action
  ask larvae[
    if count queens = 0 and not any? larvae with [to-be-queen] = true
    [set to-be-queen true set color red]
    if age >= larvae-days-to-birth
    [ifelse to-be-queen = true
      [hatch-queens 1 [set age 5 set energy energy set poisoned poisoned set destination "" set color gray set shape "queen" set size 1.1]
        die
      ]
      [hatch-workers 1 [set age 0 set energy energy set poisoned poisoned set current-action "" set destination "" set color gray set shape "worker" set size 0.8]
        die
      ]]]
end

to worker-action
  ask workers
  [
    ifelse current-action = ""
    [
     ;;Assigning current action
     if age >= 12 and any? patches with [pcolor = yellow and not any? larvae-here]
     [set current-action "gathering-food"]

     if age <= 16 and any? patches with [pcolor = gray]
     [set current-action "cleaning"]

     if age >= 4 and age < 12 and any? larvae with [energy < (max-energy-larvae * worker-feed-larvae-threshold-%)]
     [set current-action "feeding-larvae"]

     if age >= 7 and age < 12 and any? queens with [energy < (max-energy-queen * worker-feed-queen-threshold-%)]
     [set current-action "feeding-queen"]

     if energy < (max-energy-worker * worker-feed-self-threshold-%)
     [set current-action "feeding-self"]
     ]

    [
      if poison-check[
      ;;Performing assigned action
      if current-action = "cleaning"
      [
        ifelse any? patches with [pcolor = gray]
        [
        if destination = "" or not is-patch? destination or (destination != "" and [pcolor] of destination != gray)
        [set destination (min-one-of (patches with [pcolor = gray]) [distance myself])]

        ifelse patch-here = destination
        [set pcolor yellow set current-action "" set destination ""]
        [face destination fd 1]
        ]
        [set current-action "" set destination ""]
        ]

      if current-action = "gathering-food"
      [
        ifelse carrying = ""
        [
          if destination = ""
          [set destination (min-one-of (patches with [pcolor = green or pcolor = blue]) [distance myself])]

           ifelse patch-here = destination
           [ifelse [pcolor] of patch-here = blue
             [set carrying "food" ]
             [set carrying "poisoned-food"]
             set destination ""]
           [face destination fd 1]
        ]
        [
          ifelse any? patches with ([pcolor = yellow and not any? larvae-here])
          [
          if destination = "" or (destination != "" and ([pcolor] of destination != yellow or any? larvae-here))
          [set destination (min-one-of ((patches with [pcolor = yellow and not any? larvae-here]) with-min [distance patch (hive-size / 2) (hive-size / 2)]) [distance myself])]

          ifelse patch-here = destination
          [if carrying = "food"
            [set pcolor orange]

            if carrying = "poisoned-food"
            [set pcolor red]

            ask patch-here [set honey-patch-uses honey-uses]

            set destination ""
            set carrying ""
            set current-action ""]
          [face destination fd 1]]
          [set current-action "" set destination ""]
         ]
      ]

      if current-action = "gathering-honey"
      [
        if not any-honey?
        [set current-action "gathering-food"]

        ifelse destination = ""
        [set destination min-one-of (patches with [pcolor = orange or pcolor = red]) [distance myself]]
        [if [pcolor] of destination != yellow or any? larvae-here [set destination min-one-of (patches with [pcolor = orange or pcolor = red]) [distance myself]]]

        ifelse patch-here = destination
        [set current-action "" set destination ""
          if [pcolor] of patch-here = orange
          [set carrying "honey"]

          if [pcolor] of patch-here = red
          [set carrying "poisoned-honey"]

          ask patch-here
          [
            set honey-patch-uses (honey-patch-uses - 1)
            if honey-patch-uses <= 0 [set pcolor yellow set honey-patch-uses 0]
          ]
          ]
        [face destination fd 1]
        ]

      if current-action = "feeding-self"
      [
        ifelse carrying = ""
        [set current-action "gathering-honey"]
        [
          if carrying = "poisoned-honey"[set poisoned true]
          set energy (energy + honey-energy-gain)
          set carrying ""
          set current-action ""
          ]
      ]

      if current-action = "feeding-queen"
      [
        ifelse carrying = ""
        [set current-action "gathering-honey"]
        [
          move-to one-of queens ;;have to do this as queen had to use move-to in order to birth the required eggs per tick
          if carrying = "poisoned-honey"[ask one-of queens [set poisoned true]]
          ask one-of queens [set energy (energy + honey-energy-gain)]
          set carrying ""
          set current-action ""
        ]
      ]

      if current-action = "feeding-larvae"
      [
        ifelse any? larvae
        [
        if destination = "" or (destination != "" and destination = nobody)
        [set destination one-of larvae with-min [energy]]

        if destination != "" and not member? destination (larvae with-min [energy])
        [set destination one-of larvae with-min [energy]]

        ifelse [age] of destination < 3
        [
          ;;At below 3 they're fed on royal jelly so we dont' need honey
          ifelse [patch-here] of destination = patch-here
            [
              ifelse [to-be-queen] of destination = true
              [ask destination [set energy (energy + royal-jelly-energy-gain)]]
              [ask destination [set energy (energy + worker-jelly-energy-gain)]]
              set destination ""
              set current-action ""
              ]
            [face destination fd 1]
         ]
        [
          ifelse carrying = ""
          [set current-action "gathering-honey" set destination ""]
          [ifelse [patch-here] of destination = patch-here
            [
              ask destination [set energy (energy + honey-energy-gain)]
              set carrying ""
              set destination ""
              set current-action ""
              ]
            [face destination fd 1]
           ]
          ]
       ]
       [set current-action "" set destination ""]]
    ]]
  ]
end

to limit-energy
  ask queens[if energy > max-energy-queen[set energy max-energy-queen]]
  ask larvae[if energy > max-energy-larvae[set energy max-energy-larvae]]
  ask workers[if energy > max-energy-worker[set energy max-energy-worker]]
end

to age-all
  if ticks mod ticks-per-day = 0
  [ask turtles[set age (age + 1)]]
end

to death-check
  ask queens
  [
    if age > max-age-queen[if pcolor = yellow [set pcolor gray] die]
    if energy <= 0
    [if pcolor = yellow [set pcolor gray]
      die]]

  ask workers
  [
    if age > max-age-worker[die if [pcolor] of patch-here = yellow [set pcolor gray]]
    if energy <= 0 [die if [pcolor] of patch-here = yellow [set pcolor gray]]]

  ask larvae
  [if energy <= 0
    [if pcolor = yellow [set pcolor gray] die]]
end

to-report any-honey?
  report (any? patches with [pcolor = red] or any? patches with [pcolor = orange])
end

to-report poison-check
  report random 100 > poison-strength-%
end
@#$#@#$#@
GRAPHICS-WINDOW
1106
14
2389
1298
-1
-1
17.962
1
10
1
1
1
0
0
0
1
0
70
0
70
1
1
1
ticks
30.0

SLIDER
10
12
182
45
hive-size
hive-size
0
500
70.0
1
1
patches
HORIZONTAL

BUTTON
754
14
817
47
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

SLIDER
12
98
184
131
max-energy-worker
max-energy-worker
0
1000
500.0
1
1
NIL
HORIZONTAL

SLIDER
14
140
186
173
max-energy-queen
max-energy-queen
0
1000
500.0
1
1
NIL
HORIZONTAL

SLIDER
13
180
185
213
max-energy-larvae
max-energy-larvae
0
1000
500.0
1
1
NIL
HORIZONTAL

SLIDER
12
228
184
261
number-of-food-sources
number-of-food-sources
0
4
4.0
1
1
NIL
HORIZONTAL

SLIDER
12
272
184
305
poison-strength-%
poison-strength-%
0
99
50.0
1
1
NIL
HORIZONTAL

SLIDER
12
313
237
346
number-of-food-sources-poisoned
number-of-food-sources-poisoned
0
4
2.0
1
1
NIL
HORIZONTAL

SLIDER
16
638
206
671
larvae-days-to-birth
larvae-days-to-birth
12
21
12.0
1
1
days
HORIZONTAL

SLIDER
14
357
186
390
honey-energy-gain
honey-energy-gain
0
500
500.0
1
1
NIL
HORIZONTAL

SLIDER
14
592
186
625
max-age-worker
max-age-worker
35
49
42.0
1
1
NIL
HORIZONTAL

SLIDER
13
555
185
588
max-age-queen
max-age-queen
730
1825
903.0
10
1
NIL
HORIZONTAL

BUTTON
687
14
750
47
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
1

PLOT
291
169
676
319
number-of-bees
NIL
NIL
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"workers" 1.0 0 -1184463 true "" "plot count workers with [poisoned = false]"
"larvae" 1.0 0 -14454117 true "" "plot count larvae with [poisoned = false]"
"poisoned workers" 1.0 0 -13840069 true "" "plot count workers with [poisoned = true]"
"poisoned-larvae" 1.0 0 -7500403 true "" "plot count larvae with [poisoned = true]"
"queens" 1.0 0 -2674135 true "" "plot count queens"

PLOT
292
332
677
482
patch status
NIL
NIL
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"Healthy cell" 1.0 0 -987046 true "" "plot count patches with [pcolor = yellow]"
"Unclean cell" 1.0 0 -7500403 true "" "plot count patches with [pcolor = gray]"
"Honey" 1.0 0 -817084 true "" "plot count patches with [pcolor = orange]"
"Poisoned honey" 1.0 0 -2674135 true "" "plot count patches with [pcolor = red]"

PLOT
291
498
678
705
Worker actions
NIL
NIL
0.0
10.0
0.0
1.0
true
true
"" ""
PENS
"Gathering food " 1.0 0 -7500403 true "" "ifelse any? workers\n  [plot (count workers with [current-action = \"gathering-food\"]) / count workers]\n  [plot 0]"
"Getting honey" 1.0 0 -2674135 true "" "ifelse any? workers\n  [plot (count workers with [current-action = \"gathering-honey\"]) / count workers]\n  [plot 0]"
"Feeding self" 1.0 0 -955883 true "" "ifelse any? workers\n  [plot (count workers with [current-action = \"feeding-self\"]) / count workers]\n  [plot 0]"
"Feeding larvae" 1.0 0 -6459832 true "" "ifelse any? workers\n  [plot (count workers with [current-action = \"feeding-larvae\"]) / count workers]\n  [plot 0]"
"Feeding queen" 1.0 0 -1184463 true "" "ifelse any? workers\n  [plot (count workers with [current-action = \"feeding-queen\"]) / count workers]\n  [plot 0]"
"Cleaning" 1.0 0 -10899396 true "" "ifelse any? workers\n  [plot (count workers with [current-action = \"cleaning\"]) / count workers]\n  [plot 0]"
"Idle" 1.0 0 -13840069 true "" "ifelse any? workers\n  [plot (count workers with [current-action = \"\"]) / count workers]\n  [plot 0]"

SLIDER
12
440
232
473
worker-feed-self-threshold-%
worker-feed-self-threshold-%
0
1
0.85
0.01
1
NIL
HORIZONTAL

SLIDER
12
518
248
551
worker-feed-larvae-threshold-%
worker-feed-larvae-threshold-%
0
1
0.85
0.01
1
NIL
HORIZONTAL

SLIDER
12
480
248
513
worker-feed-queen-threshold-%
worker-feed-queen-threshold-%
0
1
0.85
0.01
1
NIL
HORIZONTAL

PLOT
292
10
677
160
number of queens
NIL
NIL
0.0
10.0
0.0
1.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot count queens"

SLIDER
20
685
205
718
actions-per-day
actions-per-day
240
1008
624.0
1
1
NIL
HORIZONTAL

PLOT
700
689
1092
839
queen info
NIL
NIL
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"energy" 1.0 0 -16777216 true "" "if one-of queens != nobody\n[plot [energy] of one-of queens]"
"age" 1.0 0 -7500403 true "" "if one-of queens != nobody\n[plot [age] of one-of queens]"

PLOT
697
489
1090
639
Worker info
NIL
NIL
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"energy" 1.0 0 -16777216 true "" "if any? workers [plot mean [energy] of workers]"
"age-housekeeping" 1.0 0 -7500403 true "" "if any? workers [plot count workers with [0 <= age and age < 3]]"
"age-undertakers" 1.0 0 -2674135 true "" "if any? workers [plot count workers with [3 <= age and age < 16]]"
"age-nursing" 1.0 0 -955883 true "" "if any? workers [plot count workers with [4 <= age and age < 12]]"
"age-attendant" 1.0 0 -6459832 true "" "if any? workers [plot count workers with [7 <= age and age < 12]]"
"age-forager" 1.0 0 -1184463 true "" "if any? workers [plot count workers with [12 <= age and age < max-age-worker]]"

PLOT
295
722
673
842
Larvae over time
NIL
NIL
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"age" 1.0 0 -16777216 true "" "if any? larvae[plot mean [age] of larvae]"
"energy " 1.0 0 -7500403 true "" "if any? larvae[plot mean [energy] of larvae]"

SLIDER
17
727
192
760
royal-jelly-energy-gain
royal-jelly-energy-gain
0
500
500.0
1
1
NIL
HORIZONTAL

SLIDER
17
769
189
802
ticks-per-day
ticks-per-day
0
100
96.0
1
1
NIL
HORIZONTAL

SLIDER
12
398
184
431
honey-uses
honey-uses
1
100
1.0
1
1
NIL
HORIZONTAL

SLIDER
17
810
204
843
worker-jelly-energy-gain
worker-jelly-energy-gain
0
500
500.0
10
1
NIL
HORIZONTAL

CHOOSER
13
50
152
95
number-of-workers
number-of-workers
1500 3000 7000
0

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

larvae
false
0
Circle -7500403 true true 96 76 108
Circle -7500403 true true 72 104 156
Polygon -7500403 true true 221 149 195 101 106 99 80 148

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

queen
true
0
Polygon -1184463 true false 195 150 105 150 90 165 90 225 105 270 135 300 165 300 195 270 210 225 210 165 195 150
Rectangle -16777216 true false 90 165 212 185
Polygon -16777216 true false 90 207 90 226 210 226 210 207
Polygon -16777216 true false 103 266 198 266 203 246 96 246
Polygon -6459832 true false 120 150 105 135 105 75 120 60 180 60 195 75 195 135 180 150
Polygon -6459832 true false 150 15 120 30 120 60 180 60 180 30
Circle -16777216 true false 105 30 30
Circle -16777216 true false 165 30 30
Polygon -7500403 true true 120 90 75 105 15 90 30 75 120 75
Polygon -16777216 false false 120 75 30 75 15 90 75 105 120 90
Polygon -7500403 true true 180 75 180 90 225 105 285 90 270 75
Polygon -16777216 false false 180 75 270 75 285 90 225 105 180 90
Polygon -7500403 true true 180 75 180 90 195 105 240 195 270 210 285 210 285 150 255 105
Polygon -16777216 false false 180 75 255 105 285 150 285 210 270 210 240 195 195 105 180 90
Polygon -7500403 true true 120 75 45 105 15 150 15 210 30 210 60 195 105 105 120 90
Polygon -16777216 false false 120 75 45 105 15 150 15 210 30 210 60 195 105 105 120 90
Polygon -16777216 true false 135 300 165 300 180 285 120 285

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

worker
true
0
Polygon -1184463 true false 152 149 77 163 67 195 67 211 74 234 85 252 100 264 116 276 134 286 151 300 167 285 182 278 206 260 220 242 226 218 226 195 222 166
Polygon -16777216 true false 150 149 128 151 114 151 98 145 80 122 80 103 81 83 95 67 117 58 141 54 151 53 177 55 195 66 207 82 211 94 211 116 204 139 189 149 171 152
Polygon -7500403 true true 151 54 119 59 96 60 81 50 78 39 87 25 103 18 115 23 121 13 150 1 180 14 189 23 197 17 210 19 222 30 222 44 212 57 192 58
Polygon -16777216 true false 70 185 74 171 223 172 224 186
Polygon -16777216 true false 67 211 71 226 224 226 225 211 67 211
Polygon -16777216 true false 91 257 106 269 195 269 211 255
Line -1 false 144 100 70 87
Line -1 false 70 87 45 87
Line -1 false 45 86 26 97
Line -1 false 26 96 22 115
Line -1 false 22 115 25 130
Line -1 false 26 131 37 141
Line -1 false 37 141 55 144
Line -1 false 55 143 143 101
Line -1 false 141 100 227 138
Line -1 false 227 138 241 137
Line -1 false 241 137 249 129
Line -1 false 249 129 254 110
Line -1 false 253 108 248 97
Line -1 false 249 95 235 82
Line -1 false 235 82 144 100

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.0.1
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
