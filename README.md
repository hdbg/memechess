![Logo](https://i.imgur.com/a5O4l5p.png)
# Memechess
[![CI](https://github.com/hdbg/memechess/actions/workflows/main.yml/badge.svg)](https://github.com/hdbg/memechess/actions/workflows/main.yml)

#### *"АХАХАХАХАХАХАХАХАХАХАХ ВОНО ПРАЦЮЄ НАХУЙ АХАХАХАХАХ"* - @hdbg (c)
Fully automatic chess bot with extensive configuration and scripting subsytem.

## Features
- [ ] #12
- [x] https://github.com/hdbg/memechess/issues/11

---

# Configs
Every config consists of the `events` and the following fields: `name`, `kind` and `time`.

## Name
Stands for the displayer config title and thus must be unique.
```
name = "My bullet config"
```

## Kind
Stands for the kind of config, possible values are: `[ckRage, ckLegit, ckAdvisor]`
```
kind = "ckRage"
```

## Time
Array of supported chess games timings, valid values: `[ctUltrabullet, ctBullet, ctBlitz, ctRapid, ctCorrespondence]`
```
time = ["ctBlitz", "ctRapid"]
```

**Note:** if you specify `ctCorrespondence`, then your config wouldn't be able to use `my_time` and `enemy_time` variables in formulas.

## Events
Starts with a `[[events]]` array specifier. All further statements go on the next lines.

Every config must have 1 or more event section. This section **must** have 4 fields: `condition`, `delay`, `thinktime` and `elo`
Events execution priorirty are top-to-down. That means that most upper events gots evaluated first.
If condition formula didn't matched by operator, event will be skipped without another formulas evaluation.

### Formula
A math formula which gets evaluated. 
Available operators are: `+`, `-`, `/`, `*`, `%`, `^`.

Every formula can use any of the following variables:
- `my_time` time that player have left by the last opponent move.
- `enemy_time` time that enemy have left.
- `my_score` is a last position evaluation score sent by engine.
- `enemy_score` just a negative value of `my_score`

### Condition
- `lhs` is a left formula for operator comparsion
- `op` operator which perfomes the comparsion: `[<, >, <=, >=, ==, !=]`
- `rhs` same as `lhs`, but stands in the right side of comparsion

Example condition:
```
condition = {lhs = "my_time * 2", op = "<", rhs = "30"}
```
Activates when player time left multiplied by 2 is less than 30 seconds.

**Note:** you can use any formula in `lhs` as well as in `rhs`.

### Result vars
- `delay` a time that bot will wait before sending move to chess server. **Note:** `delay` activated only after engine has sent bestmove.
- `elo` abstract value that specifies "strength" of the engine next move.
- `thinktime` time that engine will have to think on its next move. (Propably will be removed)

```
[[events]]
condition = {lhs = "my_score", op = ">", rhs = "500"}
delay = "100.0"
elo = "500 ** 3"
thinktime = "50.0"
```

---
# Scripts
Working in progress. 
