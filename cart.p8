pico-8 cartridge // http://www.pico-8.com
version 18
__lua__

-- 1. Level data
-- 2. Better shoe animation
-- 3. Checkpoints
-- 4. Gem collect animation + score
-- Hazards
-- Checkpoints
-- Sounds
-- Story points

-- useful no-op function
function noop() end

local last_step = 33 - 2
local is_ending_game = false
local game_end_countdown = 0
local stair_color = 4
local stair_offcolor = 2

-- constants
local controllers = { 1, 0 }
local level = {
  [2] = { { "text", "arrows to move", 12 } },
  [3] = { { "text", "esdf to move", 8 } },
  [6] = { { "text", "collect gems" }, { "gem", 4, 3 } },
  [7] = { { "gem", 2, 4 } },
  [9] = { { "gem", 6, 2 } },
  [11] = { { "gem", 2, 3 } },
  -- [11] = { { "gem", 5, 4 } },
  [13] = { { "text", "keep going", 14 } },
  [17] = { { "text", "thang", 12 } },
  [18] = { { "text", "love", 11 } },
  [19] = { { "text", "the", 9 } },
  [20] = { { "text", "do", 10 } },
  -- [13] = { { "gem", false, 2 } },
  [22] = { { "gem", 2, 1 }, { "gem", 5, 2 } },
  [23] = { { "gem", 2, 1 }, { "gem", 5, 2 } },
  [24] = { { "gem", 2, 1 }, { "gem", 5, 2 } },
  [25] = { { "gem", 3, 1 }, { "gem", 4, 2 } },
  [26] = { { "gem", 4, 1 }, { "gem", 3, 2 } },
  [27] = { { "gem", 5, 1 }, { "gem", 2, 2 } },
  [28] = { { "gem", 5, 1 }, { "gem", 2, 2 } },
  [29] = { { "gem", 4, 1 }, { "gem", 3, 2 } },
  [30] = { { "gem", 3, 1 }, { "gem", 4, 2 } },
  [31] = { { "gem", 2, 1 }, { "gem", 5, 2 } },
  [32] = { { "gem", 3, 1 }, { "gem", 4, 2 } },
  [33] = { { "door" }, { "text", "will you marry me?", 7, true } }
}

-- character lookup
local chars = "abcdefghijklmnopqrstuvwxyz?"
local char_to_int = {}
for i = 1, #chars do
  char_to_int[sub(chars, i, i)] = i
end

-- input vars
local buttons
local button_presses

-- render vars
local stair_offset_y
local stair_positions

-- game vars
local score
local steps
local timer_seconds
local timer_frames

-- entity vars
local entities
local shoes
local entity_classes = {
  shoe = {
    player_num = nil,
    state = "ready",
    state_frames = 0,
    offset_x = 0,
    offset_y = 0,
    warning_frames = 0,
    update = function(self)
      self.warning_frames = max(0, self.warning_frames - 1)
      self.state_frames = self.state_frames + 1
      local other_shoe = shoes[3 - self.player_num]
      -- press keys to step up stairs
      if stair_positions and self.state == "ready" and steps < last_step then
        local stair
        local segment
        -- move up
        if btnp2(2, self.player_num) then
          stair, segment = self.stair + 1, self.segment
        -- move up + right
        elseif btnp2(1, self.player_num) then
          stair, segment = self.stair + 1, self.segment + 1
        -- move up + left
        elseif btnp2(0, self.player_num) then
          stair, segment = self.stair + 1, self.segment - 1
        -- move down
        elseif btnp2(3, self.player_num) then
          stair, segment = self.stair - 1, self.segment
        end
        -- actually initiate the move
        if self:is_valid_move(stair, segment) then
          self:step(stair, segment)
        elseif stair and segment and stair > self.stair then
          self.string:show_warning()
          self.warning_frames = 8
        end
      end
      -- animate stepping up stairs
      if self.state == "stepping" then
        local f = 8 - self.state_frames
        self.offset_x = self.offset_x * f / (f + 1)
        self.offset_y = self.offset_y * f / (f + 1)
        -- finish stepping
        if self.state_frames >= 8 then
          self:set_state("ready")
        end
      end
      -- check for gem collections
      if self.state == "ready" then
        for entity in all(entities) do
          if entity.stair == self.stair and entity.segment == self.segment then
            if entity.class_name == "gem" then
              entity:collect()
            end
          end
        end
      end
    end,
    draw = function(self, x, y)
      x -= self.offset_x + 7.5
      y -= self.offset_y + 10.5
      if self.state == "stepping" then
        y -= 6 * cos((self.state_frames - 1) / 32)
      end
      if self.player_num == 2 then
        pal(8, 12)
        pal(2, 1)
      end
      local sprite
      if y > 85 then
        sprite = 1
      else
        sprite = 2
      end
      sspr(12 * (sprite - 1), 0, 12, 19, x + ((self.warning_frames > 0) and (2 * (self.warning_frames % 2) - 1) or 0), y, 12, 19, x > 64)
      self.visual_x = x
      self.visual_y = y
    end,
    is_valid_move = function(self, stair, segment)
      local other_shoe = shoes[3 - self.player_num]
      return stair and segment and (stair != other_shoe.stair or segment != other_shoe.segment) and 1 <= stair and stair <= 2 and 1 <= segment and segment <= 6 and other_shoe.segment - 3 <= segment and segment <= other_shoe.segment + 3
    end,
    set_state = function(self, state)
      self.state = state
      self.state_frames = 0
    end,
    step = function(self, stair, segment)
      self:set_state("stepping")
      local starting_stair_position = stair_positions[self.stair].segments[self.segment]
      self.stair = stair
      self.segment = segment
      local ending_stair_position = stair_positions[self.stair].segments[self.segment]
      self.offset_x = ending_stair_position.x - starting_stair_position.x
      self.offset_y = ending_stair_position.y - starting_stair_position.y
    end
  },
  shoe_string = {
    render_layer = 6,
    warning_frames = 0,
    init = function(self)
      self.points = {}
      local prev_point
      for i = 1, 11 do
        local point = self:add_point()
        if prev_point then
          add(prev_point.connections, point)
          add(point.connections, prev_point)
        end
        prev_point = point
      end
      self.shoe_points = { self.points[1], self.points[#self.points] }
      self.mid_point = self.points[6]
      for bias = -1, 1, 2 do
        prev_point = self.mid_point
        for i = 1, 3 do
          local point = self:add_point(bias)
          if prev_point then
            if prev_point != self.mid_point then
              add(prev_point.connections, point)
            end
            add(point.connections, prev_point)
          end
          prev_point = point
        end
      end
    end,
    update = function(self)
      for point in all(self.points) do
        for other_point in all(point.connections) do
          self:accelerate_point_towards(point, other_point.x, other_point.y)
        end
      end
      -- apply point velocity
      for point in all(self.points) do
        if point.bias then
          point.vx += point.bias / 10
          point.vy += 0.4
        else
          point.vy += 0.8 - 0.22 * abs(shoes[1].segment - shoes[2].segment)
        end
        point.vx = mid(-5, point.vx, 5)
        point.vy = mid(-5, point.vy, 5)
        point.x += point.vx
        point.y += point.vy
        point.vx *= 0.87
        point.vy *= 0.87
      end
      -- move shoe points to shoes
      for p = 1, 2 do
        if shoes[p].visual_x and shoes[p].visual_y then
          self.shoe_points[p].x = shoes[p].visual_x + 5.5
          self.shoe_points[p].y = shoes[p].visual_y + 4.5
          self.shoe_points[p].vx = 0
          self.shoe_points[p].vy = 0
        end
      end
      self.warning_frames = max(0, self.warning_frames - 1)
    end,
    draw = function(self)
      for point in all(self.points) do
        for other_point in all (point.connections) do
          line(point.x, point.y, other_point.x, other_point.y, self.warning_frames > 17 and 8 or 7)
        end
      end
      local x, y = self.mid_point.x, self.mid_point.y
      if self.warning_frames % 6 >= 3 then
        sspr(121, 58, 7, 10, x - 3, y - 4)
      end
    end,
    add_point = function(self, bias)
      local point = {
        x = 64,
        y = 64,
        vx = 0,
        vy = 0,
        bias = bias,
        connections = {}
      }
      add(self.points, point)
      return point
    end,
    accelerate_point_towards = function(self, point, x, y)
      local dx = x - point.x
      local dy = y - point.y
      local square_dist = dx * dx + dy * dy
      local dist = sqrt(square_dist)
      if dist > 2 then
        point.vx += 0.95 * (dist - 2) * dx / dist
        point.vy += 0.95 * (dist - 2) * dy / dist
      end
    end,
    show_warning = function(self)
      self.warning_frames = 25
    end
  },
  gem = {
    gem_type = nil,
    has_been_collected = false,
    collect_frames = 0,
    offset_y = 0,
    update = function(self)
      if self.has_been_collected then
        self.collect_frames += 1
        self.offset_y += -3 + 0.3 * self.collect_frames
        if self.collect_frames > 14 then
          self:despawn()
        end
      end
    end,
    draw = function(self, x, y)
      x += -4.5
      y += -7.5 + self.offset_y
      local sprite
      if self.has_been_collected then
        sprite = (self.collect_frames % 4 < 2) and 1 or 2
      elseif y > 58 then
        sprite = 4
      else
        sprite = 3
      end
      sspr(86 + 9 * (self.gem_type - 1), 70 + 12 * (sprite - 1), 9, 12, x, y)
    end,
    collect = function(self)
      if not self.has_been_collected then
        score += 1
        self.has_been_collected = true
        self.offset_y = -12
      end
    end
  },
  stair_text = {
    render_layer = 3,
    color = 7,
    segment = 3,
    is_special = false,
    draw = function(self, x, y)
      if not self.is_special or (is_ending_game and game_end_countdown > 350) then
        local scale = (12.4 - 1.2 * self.stair) / 10
        local width = draw_text(self.text, 63, y + 12.5 * scale, 6 - self.stair, true)
        if self.is_special then
          if game_end_countdown > 380 then
            pal(7, 7)
          elseif game_end_countdown > 370 then
            pal(7, 6)
          elseif game_end_countdown > 360 then
            pal(7, 5)
          else
            pal(7, 1)
          end
        else
          pal(7, self.color)
        end
        draw_text(self.text, 65 - width / 2, y + 12.5 * scale, 6 - self.stair, false)
      end
    end
  },
  door = {
    segment = 1,
    open_amount = 93,
    update = function(self)
      if is_ending_game and game_end_countdown > 25 then
        self.open_amount = max(0, self.open_amount - 0.5)
      end
    end,
    draw = function(self, x, y)
      local stair = stair_positions[self.stair]
      if stair_positions[self.stair] then
        local left = stair_positions[self.stair].top_left_x + 1
        local right = stair_positions[self.stair].top_right_x - 1
        local y = stair_positions[self.stair].top_y - 2
        rectfill(left, 0, right, y, 2)
        if self.open_amount < 93 then
          sspr(0, 72, 86, 56, 21, 13)
        end
        rectfill(left + (93 - self.open_amount) ^ 2 / 93, 0, right, y, stair_offcolor)
        rect(left, 0, right, y, stair_color)
        if game_end_countdown > 275 then
          pal(12, 0)
          sspr((self.frames_alive % 8 < 4) and 86 or 101, 118, 15, 10, 48, 55)
          if game_end_countdown < 285 then
            sspr(122, 110, 6, 8, 42, 50)
          end
        end
      end
    end
  }
}

function _init()
  buttons = { {}, {} }
  button_presses = { {}, {} }
  stair_offset_y = 147
  score = 0
  steps = 0
  timer_seconds = 45
  timer_frames = 0
  entities = {}
  local string = spawn_entity("shoe_string", {})
  shoes = {
    spawn_entity("shoe", {
      player_num = 1,
      stair = 1,
      segment = 3,
      string = string
    }),
    spawn_entity("shoe", {
      player_num = 2,
      stair = 1,
      segment = 4,
      string = string
    })
  }
  for i = 1, 5 do
    load_level_step(i)
  end
end

function _update()
  if game_end_countdown == 100 then
    stair_color, stair_offcolor = 2, 1
  elseif game_end_countdown == 175 then
    stair_color, stair_offcolor = 1, 0
  end
  -- update timer
  timer_frames -= 1
  if timer_frames <= 0 then
    timer_seconds -= 1
    timer_frames = 30
    if timer_seconds <= 0 then
      timer_seconds = 0
      timer_frames = 0
    end
  end

  if is_ending_game then
    game_end_countdown += 1
  end

  -- keep track of button presses
  local p
  for p = 1, 2 do
    local i
    for i = 0, 5 do
      button_presses[p][i] = btn(i, controllers[p]) and not buttons[p][i]
      buttons[p][i] = btn(i, controllers[p])
    end
  end

  -- scroll stairs
  if (shoes[1].stair > 1 and shoes[2].stair > 1) or stair_offset_y < 147 then
    stair_offset_y = stair_offset_y + 4
  end
  if stair_offset_y >= 166 then
    stair_offset_y = 127
    steps += 1
    for entity in all(entities) do
      if entity.stair then
        entity.stair -= 1
      end
    end
    if steps == last_step then
      game_end_countdown = 0
      is_ending_game = true
    end
    load_level_step(steps + 5)
  end

  -- update each entity
  for entity in all(entities) do
    entity.frames_alive += 1
    entity:update()
  end

  -- remove dead entities
  filter_list(entities, function(entity)
    return entity.is_alive
  end)

  -- sort entities for rendering
  sort_list(entities, is_rendered_on_top_of)
end

function _draw()
  -- clear the screen
  cls()

  -- draw vertical purple stripes for the walls
  for x = 1, 127, 2 do
    line(x + (x > 64 and 1 or 0), 0, x + (x > 64 and 1 or 0), 128, stair_offcolor)
  end

  -- draw the stairs and record their visual positions
  stair_positions = {}
  local width, rise_left = calc_stair_size(stair_offset_y)
  local bottom_width, bottom_y
  for y = flr(stair_offset_y), 0, -1 do
    -- each stair has six segments running horizontally
    local width_2, rise_left_2 = calc_stair_size(y)
    -- advance up each stair
    if rise_left > 0 then
      rise_left -= 1
      -- record the bottom of the step
      if rise_left <= 0 then
        bottom_width = width
        bottom_y = y - 1
      end
    else
      width -= 1
    end
    if width <= width_2 then
      width = width_2
      rise_left = rise_left_2
      if bottom_width and bottom_y then
        -- draw parts of stairs
        local top_y, top_width = y + 2, width - 1
        local top_left_x = 64 - top_width / 2 - 1
        local bottom_left_x = 64 - bottom_width / 2
        local top_right_x = 64 + top_width / 2 + 1
        local bottom_right_x = 64 + bottom_width / 2
        local stair = {
          top_y = top_y,
          top_left_x = top_left_x,
          top_right_x = top_right_x,
          bottom_y = bottom_y,
          bottom_left_x = bottom_left_x,
          bottom_right_x = bottom_right_x,
          top_width = top_width,
          bottom_width = bottom_width,
          segments = {}
        }
        -- draw the lines between stair segments
        for p = 1 / 6, 5.5 / 6, 1 / 6 do
          line(top_left_x + (top_right_x - top_left_x) * p, top_y, bottom_left_x + (bottom_right_x - bottom_left_x) * p, bottom_y, stair_offcolor)
        end
        -- record segment positions
        local middle_y = (top_y + bottom_y) / 2
        local middle_left_x = (top_left_x + bottom_left_x) / 2
        local middle_right_x = (top_right_x + bottom_right_x) / 2
        for p = 1 / 12, 5.5 / 6, 1 / 6 do
          add(stair.segments, {
            x = middle_left_x + (middle_right_x - middle_left_x) * p,
            y = middle_y
          })
        end
        add(stair_positions, stair)
        bottom_width = nil
        bottom_y = nil
      end
    end

    -- draw the stairs
    local left_x = 64 - width / 2
    local right_x = 64 + width / 2 - 0.5
    -- draw the purple part of the stairs
    if rise_left > 0 then
      line(left_x, y, right_x, y, 0)
      pset(left_x, y, stair_offcolor)
      pset(right_x, y, stair_offcolor)
      if rise_left <= 2 then
        line(left_x, y, right_x, y, stair_offcolor)
      end
    -- draw the brown part of the stairs
    else
      line(left_x, y, right_x, y, stair_color)
    end
  end

  -- draw entities
  for entity in all(entities) do
    if not entity.stair then
      entity:draw(0, 0)
    elseif stair_positions[entity.stair] then
      local position = stair_positions[entity.stair].segments[entity.segment]
      local x, y = position.x, position.y
      pal()
      entity:draw(x, y)
      pal()
    end
  end

  -- draw black bar along the top
  rectfill(0, 0, 127, 12, 0)

  if not is_ending_game then
    -- draw the score
    local score_text = (score == 0 and "0" or score .. "00")
    print(score_text, 127 - 4 * #score_text, 4, 7)

    -- draw the number of steps taken so far
    local step_text = steps .. " steps"
    print(step_text, 2, 4, 7)

    -- draw the timer
    local timer_text = (timer_seconds < 10 and "0" or "") .. timer_seconds .. "." .. min(9, flr(10 * timer_frames / 30))
    print(timer_text, 62 - 2 * #timer_text, 4, 7)
    sspr(116, 118, 7, 7, 71, 3)
  end
end

function load_level_step(step)
  if level[step] then
    for action in all(level[step]) do
      local stair = step - steps
      if action[1] == "gem" then
        spawn_entity("gem", {
          stair = stair,
          segment = action[2] or rnd_int(1, 6),
          gem_type = action[3] or rnd_int(1, 4)
        })
      elseif action[1] == "text" then
        spawn_entity("stair_text", {
          text = action[2],
          stair = stair,
          color = action[3] or 7,
          is_special = action[4]
        })
      elseif action[1] == "door" then
        spawn_entity("door", {
          stair = stair
        })
      end
    end
  end
end

function calc_stair_size(y)
  return flr((60 + 60 * y / 127) / 2) * 2, flr(6 + y / 10)
end

function btn2(button_num, player_num)
  return buttons[player_num][button_num]
end

function btnp2(button_num, player_num, consume_press)
  if button_presses[player_num][button_num] then
    if consume_press then
      button_presses[player_num][button_num] = false
    end
    return true
  end
end

-- removes all items in the list that don't pass the criteria func
function filter_list(list, func)
  local item
  for item in all(list) do
    if not func(item) then
      del(list, item)
    end
  end
end

-- bubble sorts a list
function sort_list(list, func)
  local i
  for i=1, #list do
    local j = i
    while j > 1 and func(list[j - 1], list[j]) do
      list[j], list[j - 1] = list[j - 1], list[j]
      j -= 1
    end
  end
end

-- spawns an instance of the given entity class
function spawn_entity(class_name, args, skip_init)
  local class_def = entity_classes[class_name]
  local entity
  if class_def.extends then
    entity = spawn_entity(class_def.extends, args, true)
  else
    -- create a default entity
    entity = {
      render_layer = 5,
      -- life cycle vars
      is_alive = true,
      frames_alive = 0,
      -- functions
      init = noop,
      update = noop,
      draw = noop,
      despawn = function(self)
        if self.is_alive then
          self.is_alive = false
          self:on_despawn()
        end
      end,
      on_despawn = noop
    }
  end
  -- add class-specific properties
  entity.class_name = class_name
  local key, value
  for key, value in pairs(class_def) do
    entity[key] = value
  end
  -- override with passed-in arguments
  for key, value in pairs(args or {}) do
    entity[key] = value
  end
  if not skip_init then
    -- add it to the list of entities
    add(entities, entity)
    -- initialize the entitiy
    entity:init()
  end
  -- return the new entity
  return entity
end

-- random number generators
function rnd_int(min_val, max_val)
  return flr(min_val + rnd(1 + max_val - min_val))
end

function rnd_num(min_val, max_val)
  return min_val + rnd(max_val - min_val)
end

-- courtesy of felice: https://www.lexaloffle.com/bbs/?tid=3217
function smallcaps(s)
  local d=""
  local l,c,t=false,false
  for i=1,#s do
    local a=sub(s,i,i)
    if a=="^" then
      if(c) d=d..a
      c=not c
    elseif a=="~" then
      if(t) d=d..a
      t,l=not t,not l
    else 
      if c==l and a>="a" and a<="z" then
        for j=1,26 do
          if a==sub("abcdefghijklmnopqrstuvwxyz",j,j) then
            a=sub("\65\66\67\68\69\70\71\72\73\74\75\76\77\78\79\80\81\82\83\84\85\86\87\88\89\90\91\92",j,j)
            break
          end
        end
      end
      d=d..a
      c,t=false,false
    end
  end
  return d
end

-- returns true if a is rendered on top of b
function is_rendered_on_top_of(a, b)
  return (a.render_layer == b.render_layer) and (a.stair < b.stair) or (a.render_layer > b.render_layer)
end

function draw_text(text, x, y, size, dry_run)
  if size <= 1 then
    if not dry_run then
      print(smallcaps(text), x, y, 7)
    end
    return 4 * #text
  elseif size <= 2 then
    if not dry_run then
      print(text, x, y, 7)
    end
    return 4 * #text
  else
    local curr_x = x
    for i = 1, #text do
      local c = sub(text, i, i)
      local n = char_to_int[c]
      if n then
        local spr_x, spr_y, spr_width, spr_height = 0, 45, 6, 9
        -- second row
        if n > 14 then
          spr_x = 6 * (n - 15)
          spr_y = 63
          -- w
          if n == 23 then
            spr_width += 1
          elseif n > 23 then
            spr_x += 1
          end
        -- first row
        else
          spr_x = 6 * (n - 1)
          spr_y = 45
          -- i
          if n == 9 then
            spr_width -= 4
          elseif n > 9 then
            spr_x -= 4
          end
          -- m
          if n == 13 then
            spr_width += 1
          elseif n > 13 then
            spr_x += 1
          end
          -- n
          if n == 14 then
            spr_width += 1
          elseif n > 14 then
            spr_x += 1
          end
        end
        local gap = spr_width
        if true then -- size <= 3 then
          spr_y -= 9
          if n ~= 9 and n~= 13 and n ~= 14 and n ~= 23 and (size ~= 3 or (n ~= 20 and n ~= 25)) then
            gap -= 1
          end
        end
        if not dry_run then
          sspr(spr_x, spr_y, spr_width, spr_height, curr_x, y)
        end
        curr_x += gap + 1
      else
        curr_x += 2
      end
    end
    return curr_x - x
  end
end

__gfx__
00000888880000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00008888888000000000000000000000000000008888800000000000000000000000000000000000000000000000000000000000000000000000000000000000
00088787888800000888880000000888880000088888880000000000000000000000000000000000000000000000000000000000000000000000000000000000
00088878888800088788888000008888888000088788888000000000000000000000000000000000000000000000000000000000000000000000000000000000
00888787888800887878888000088878888000887878888000000000000000000000000000000000000000000000000000000000000000000000000000000000
00888878888800888888888000888787888800888888888000000000000000000000000000000000000000000000000000000000000000000000000000000000
08888888888808822228888008888888888808888888888000000000000000000000000000000000000000000000000000000000000000000000000000000000
08822222888808222222888008822222888808822228887000000000000000000000000000000000000000000000000000000000000000000000000000000000
08222222288708222222887008222222288808222222887000000000000000000000000000000000000000000000000000000000000000000000000000000000
88222222288788277222887088222222288788222222887000000000000000000000000000000000000000000000000000000000000000000000000000000000
88222222288788877888887088227722888788277222887000000000000000000000000000000000000000000000000000000000000000000000000000000000
88227722888778888888870088887788888778877888870000000000000000000000000000000000000000000000000000000000000000000000000000000000
78887788887078888888870088888888887778888888870000000000000000000000000000000000000000000000000000000000000000000000000000000000
78888888887078888888770078888888887078888888700000000000000000000000000000000000000000000000000000000000000000000000000000000000
78888888877077888887700078888888877077888887700000000000000000000000000000000000000000000000000000000000000000000000000000000000
77888888777007777777700077888888777007777777700000000000000000000000000000000000000000000000000000000000000000000000000000000000
07777777770000777777000077777777777000777777000000000000000000000000000000000000000000000000000000000000000000000000000000000000
07777777770000000000000007777777770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00777777700000000000000000777777700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
07770077770007770077770077777077777007770077077077007770770770770000770007777007700000000000000000000000000000000000000000000000
77777077777077777077777077777077777077777077077077007770770770770000777077777707700000000000000000000000000000000000000000000000
77077077077077077077077077000077000077000077777077000770777700770000777777777777700000000000000000000000000000000000000000000000
77777077770077000077077077770077770077077077777077000770777770770000777777777777700000000000000000000000000000000000000000000000
77077077077077077077077077000077770077007077077077770770770770770000770707777077700000000000000000000000000000000000000000000000
77077077777077777077777077777077000077777077077077777770770770777770770007777007700000000000000000000000000000000000000000000000
77077077770007770077770077777077000007770077077077077700770770777770770007777007700000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
07777077777007777077770077777777777707777077007777000777770077770000770007777000770000000000000000000000000000000000000000000000
77777777777777777777777077777777777777777777007777000777770077770000777077777700770000000000000000000000000000000000000000000000
77007777007777007777077777000077000077007777007777000077770777770000777777777770770000000000000000000000000000000000000000000000
77007777777077000077007777777077000077000077007777000077777770770000777777777777770000000000000000000000000000000000000000000000
77777777777777000077007777777077777077000077777777000077777700770000770707777077770000000000000000000000000000000000000000000000
77777777007777000077007777000077777077077777777777770077777770770000770007777007770000000000000000000000000000000000000000000000
77007777007777007777007777000077000077007777007777770077770777770000770007777000770000000000000000000000000000000000000000000000
77007777777777777777777777777777000077777777007777777777770077777777770007777000770000000000000000000000000000000000000000000000
77007777777007777077777077777777000007777077007777077770770077777777770007777000770000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
07770077770007770077770007770077777777077077077077000777707707700777777700777700000000000000000000000000000000000000000000000000
77777077777077777077777077777077777777077077077077000777707707700777777700777700000000000000000000000000000000000000000000000000
77077077077077077077077077000000770077077077077077070777777707700770077700007700000000000000000000000000000000000000000000000000
77077077777077077077777007770000770077077077077077777770777007777770777000077700000000000000000000000000000000000000000000008000
77077077770077070077770000077000770077077077777077777777777700777707770000077000000000000000000000000000000000000000000000008000
77777077000077777077077077777000770077777007770077707777707700077007777700000000000000000000000000000000000000000000000008008008
07770077000007777077077007770000770007770000700077000777707700077007777700077000000000000000000000000000000000000000000000800080
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
07777077777007777077777007777077777777007777007777000777700777700777777770777700000000000000000000000000000000000000000000000000
77777777777777777777777777777777777777007777007777000777700777700777777777777770000000000000000000000000000000000000000000800080
77007777007777007777007777000000770077007777007777000777707777700770007777700770000000000000000000000000000000000000000008008008
77007777007777007777007777777000770077007777007777000770777707777770077700007770000000000000000000000000000000000000000000008000
77007777777777007777777007777700770077007777007777070770777700777700777000077700000000000000000000000000000000000000000000008000
77007777777077007777777700007700770077007777007777777777777770077007770000077000000000000000000000000000000000000000000000000000
77007777000077077077077777007700770077007707777077777777770770077007700000000000000000000000000000000000000000000000000000000000
77777777000077777777007777777700770077777707777077707777700770077007777770077000000000000000000000070000000000000000000000000000
07777077000007777777007707777000770007777000770077000777700770077007777770077000000000000000000000777000007777000000000000000000
fc777777777777cffcfc77777777fcfcfccc7c777f7777777fffccfcfc7777c77ccfc777f7ffffccfcfcff007777700000777000077777700077777700000000
77777c777c7cfcc7cfcfff777fcfcfccc7c7c777f7fc777cfcfcfcccc777fff7ff77777f7f7f7fffcfcffc077777770007777700077777700077777700000000
7777c7c7c7fccf7cff7c7ccccc7ccccccc7777f77fcf7fcfcfcfcccc7c7f7c7fcf77ccfffcccfccccccccc077777770007777700077777700077777700000000
c77c7c7ccccfcfcfcfccccccccccc7c7777f7f7ff7fcfcfcccfcc7777777c7f7f77cfcfcfcfcc77c7cfcff077777770007777700077777700077777700000000
7cfcccc7fcccc7fcfcccc777777c77f777c7ffffcccccfcfcc777c7777cccc7ffccc7cc777c777ffcfcffc077777770007777700077777700077777700000000
ffcc7fff77777ccccc7777777cf7c7c7ccccccccfccc777f77c7c7cfc77c77cc7fcfcffc77777ffcffffcc007777700007777700077777700077777700000000
c7777fc777c77c77777f7ff7cfcc7cc77cc77ccccc777c77fcfcfcc777f7ccc77cf7fccfccfcffcfccc779000777000007777700077777700077777700000000
777cfcffcfcc7cf7c7f7cc7cfcfcc77ccc7777cfc777cffccccc777c77cc7777fccc7776cfcfcffff7779d000070000000777000007777000077777700000000
77cfcfccfcffcf7c7fffcfcccccc7ccfc777677cfcfcffccc7c77777ff7c7fcfccc7776666fcfcf7777665000000000000000000000000000000000000000000
cccc777777ccfcffc7cccccccccccccc77776d9cccffcccc777f7cffc7cffcfcc77769d656ddfff7776655000000000000000000000000000000000000000000
fcf777767977cccc7ccccc7c7777cccc77777d66cfccccc7c7c7cf7cffffcfccf77696655d5dddff7ed5d5000000000000070000000000000000000000000000
777f6f69696796cccc7c7777fcf7ffcf67777f95dccff77c7cc7c7ccc7ccccff776dfe5d55555ddd79dd55000000000000707000077777700000000000000000
7777766dfdf66dddc7c77cffccccccf7d9d677d559fffccccccc7cc7c7cc77f77dd9e5d5dfd55ddf7ed5d5077777770007007700700007770777777770000000
777695965d5dd555ddfcccccccfc9fed675d775d5dccc7c77ccccc7c7cc77f79d577d555df55d5fd9e5d55700070777007007700700077770700077770000000
fe95d5d5d5557655555cfccfcfc9fe7d775df7f555777ccccc7cc7cccc777fdd57e9d55ddf955ddfedd555700700777070070770700707770700707770000000
7e66565d55d767fd5d555cfcfc9fe9d9795d67df555ccccc79ccfcfcc77e955f77edd55d57ed55ddeddd5d707000777070700770707007770707007770000000
ed9ddf55dd776dddd5d555cffe779df77d5ddffdd55c7777669fccccc7fef5f7fe9555ddf77ed55dfd7d55070007770077000770770007770770007770000000
69dd55d5d775dfd65d55555fef9dd7799555fdf6d55f77e665ddffcff7eddf9df9555d5df97f9d5ddf77d5007077700070000770700007770700007770000000
fdd5555d77dd5ddf55ddf555fddff7f5df55ddff5d55fe9d555dddfd7fedf9d59d5555d5d7979d55dfdfdd000777000007007700700007770700007770000000
dd5d5d9f7f55ddf95ddff555ddfe7f95d555dddddf5559d555d55dd79ed55d5d5d55d55d7777fed5ddfffd000070000000777000077777700777777770000000
f5d59f77955ddd955ddf55255fe7fd5fd5d55ddd5dd555d55d5ff97fd5d7f555dd5555dd979777fddddf9d000000000000000000000000000000000000000000
dd59767ed555df95555d525fd6f7555f5dd5dddf55d5555ddff99dfdfd7775df95555ddf7f7f7f7fddf9dd000000000000000000000000000000000000000000
55d7ffef555d55555d5d555df7e955dddd5d5f7f5555dd55fd5d9dd5df7fd599d55d5df9f9f9f7f9d5fddf000000000000000000000000000000000000000000
d9fffedf552d5dd5d5555df977e5555fd5df77f555d55d5d5dd55d55fdfdd5dd5555ddd99f9f9f9dddddfd000000000000070000000000000000000000000000
9ffd955d9555d5555dd5f77f77e5d55d5df9f955255555d5555555ff9ddd595d552ddd9ff9fdd99dd5ddd90000000000007770000077b7000000000000000000
f9df555dd95225d5d5979d99fe7555d59fff6f52555dd55d55fd595dd9d5d5dd552dd9d6dfd5dfdfd55ddf0077787000077cc700077bbb70007777af00000000
ddf95255ddd55d5d5d77d955df7d255959f69d52d55d5555d5d5dd55dd5d5d555252ddd6fdddfd99dd55dd07878ee70007cccc0007bbbbb00077aaaa00000000
d95552525555ddddaf9f955df7d555d5f969d9525d55d55d5d955dd5d52dddd5ddddd5df69d5d9d99dd2dd08888888000c7ccc0007bbbbb0007a7aaa00000000
555525255d5d5da99ff525d9d9525d599f9d9d55dd555d5552d55d9522d5d5d25d5ddddd9d5dd5dd9d5d2d008e8880000cccc10007bb7b30007aaaa900000000
d5d55255d5d5d595a922dd9d9d9d22d5999d522d55d5d5552d552d522d5ddddd25dd5ad9ddd295d9ddd2d2000888000001cc11000bbbb33000aa9a9900000000
55522225255da525522d55d5d9d55d595a5d2255d55dd22dad2ddd2ddd2d2d22d2d2d5dd2d2ddd2d2d2d2200228220000211120000b3330000f9999900000000
242222225242222225255522525252a5d522ddd5dd5d22d2222d2dd2222222222d2dd2d2aad2222242222d022222220022222220022222200022222200000000
34342434444334342242242224542322222222555232222444242222344444422424aa2aaaa24234434422002222200002222200002222000022222200000000
bab3b343b3b3bb4b3b434b3b3b34bbaa3b3b3aa4bbab4b4b3bbaba43b4a3aaabb3aaaa9aaa94b3bb3b43b4000000000000000000000000000000000000000000
bbaba33bbbaaab3bbabbbbbbabbb33bab3babaaab3b33333bbbbba34333aabba3baa9949aa9b3ab3bb3b43000000000000070000000000000000000000000000
3b3b33b3bbbababbbbb3bbbbbbb3b343bb3b3bbb3b3b333b3a3b3b3b3bb3bbbbbbb9a4aa9bb3bbbbb3bb3b00000000000077700007777b700000000000000000
33b333bbb3bbbbbbb3bb33b3bb33bb34b3bbab3ab33333b333b3b3bbbb3bbb3b3aaaaaaa99bb33b3bb3bb30777778700077cc70077bbbbb70777777af0000000
bbb5b3b3bb3abbba3b33b3b3b3bb33343b3bbbbb3333333bbbaabababba3b3bbbaaa9aa99b3bbb333bb333787ee8ee70077ccc007b7bbbbb0777aaaaa0000000
aabbbbbb33bb3bbbb33b3b3b3bb3333abaab3b33a3b3aabaaabaabbba3b3bbbbbba9ba93bbbb3bb3b3bb337e878eeee07ccccc7077bbbbbb077a7aaaa0000070
bbbaabbbbbbbb33b33b33bb3b333babbabbab3333b3aababaaaabab3bb3bbb3b3bbb33b33b33333333bbb38888888880c7ccccc07bbbb7b307a7aaaaa0000070
abbabbbbbb3b3b333b3bb3b3333b3bbaaab3bb3ba3b3bbabbabbbbbbbb3bb3aaaa39b3b33333bbbb333bb308e8888800c7cccc107bbbb7b3077aaaaa90700007
ababbbabb3b3333b3b3b333349b3ba3bba3b3bb3bbbabb3bbbb3bbaab3baaa49a9aa93b3bb3bb3bbb333bb008e888000cccccc107bbbbbb307aaafaa90070007
bbbbbbbbbb3b33b3b3b33349bbb33bbb3bbbbb3b3b3b3bb3b3bbba4aabbaa99449aa93b3bb3b333bbb33bb000888000001cc1100bbbbbb330aaa9aa990007000
abb3bb3b33b3b33b3333344bb33bb3b3b3b33b33a3a3b3babbbbba49abbbaabaa9b9bbb3b33b3333bbb3bb0222822200021112000bb333300fa9999990000700
bbbbbbb3b3b33b3333344ab3b3b3bb3bb3bbbbbbbaabbbbababbbaaa3b33bbbaaabb33b3bbb3333bbbb333222222222022222220222222220222222220000000
bb3b3b3b3b33333333444b3b3b3bbbb3bbbbb3bbbbabbbbabbaab33bb3bbb3bbbbb333b3bbbb333b3bbb33022222220002222200022222200222222220777700
bbbbbbb3b33b333344a4bb33b3b3bbbbbab3bbb3abbbabaaaaaa3b33b33b3b3bb33b33b33b333b3b33b3330000000000000000000000000000c0007770000000
bbb3b3bb3333333494bbbb3b3bbb3b3bbbbbbbbaaabaaabab3333b33b3bb3b3bb3333b333b3b3b3b33b333001cc000000cc00001cc00000000cc070707000000
b3bb3bb333333349943b33bbbbbbbbbbaaaabbbbaaaaaab33bbb3b33b33b3b3bb3333bb3333b3b3bb3bb33cccccc000000cc0cccccc000000ccc700700700000
bbb3b33b33334994bb3b3b3bb3bb3b3bababaabbabbaa3bbbb3b3bb3bb3b3b3bb33b3b3b333b33b3b33b33ccc5cc1cccc0cc0ccc5cc1cccc0cc0700770700000
3b3b333333349a4b33b3bbbbbbbbbbbbbb3ba3abaa33bb33bb3b3bb3b3b33333b33b333b333333b33333330ecccc1cccccc000ecccc1cccccc00700000700000
b3bbb33339499bb3ab3bb3bb3bbbbbbabbbaabb333bb33b3bb3b33b333b33333b33b333b33333333333333ecccc1ccccc0000ecccc1ccccc0000070007000000
b33b333344999b33b333bb3b3b3b3bbabbb3333bb333339999994999949493333333333333333333333333e656ccccc0000000656ccccc000000007770000123
3bb3333499999333b333333333b3bbbb3b99999499999949444444494449499499999999443333333333330161ccc000000000161ccc00000000000000004567
3b3b33349494444444444439999949999999494949444444444444444444444449444444449944943333330cc0cc0000000000cc0cc0000000000000000089ab
444444444444444444444444444444444444444444444444444444444444444444444944444444444444330c00c00000000000c00c000000000000000000cdef
