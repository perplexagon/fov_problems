-- 
-- FOV, based on: http://journal.stuffwithstuff.com/2015/09/07/what-the-hero-sees/
-- 

function make_shadow(start_point, end_point)
  local Shadow = {
    start_point = start_point,
    end_point = end_point
  }

  function Shadow:contains(other_shadow)
    --Returns true if other_shadow is completely covered by this shadow.
    return self.start_point <= other_shadow.start_point and self.end_point >= other_shadow.end_point
  end

  return Shadow
end


function project_tile(row, col)
  local top_left =  col / (row + 2)
  local bottom_right = (col + 1) / (row + 1) 

  return make_shadow(top_left, bottom_right)
end


function make_shadow_line()
  local Shadowline = {
    shadows = {}
  }

  function Shadowline:is_in_shadow(projection_shadow)
    for _, shadow in pairs(self.shadows) do
      if shadow:contains(projection_shadow) then return true end
    end
    return false
  end

  function Shadowline:add(shadow)
    -- figure out where to slot the new shadow in the list.
    local index = 1
    
    for test_index = index, #self.shadows do
      -- Stop when we hit the insertion point.
      index = test_index
      if (self.shadows[index].start_point >= shadow.start_point) then 
        break
      end
    end

    -- The new shadow is going here. See if it overlaps the previous or next.
    local overlap_prev
    if (index > 1 and self.shadows[index-1].end_point > shadow.start_point) then
      overlap_prev = self.shadows[index-1]
    end

    local overlap_next
    if (index <= #self.shadows and self.shadows[index].start_point < shadow.end_point) then
      overlap_next = self.shadows[index]
    end

    -- Insert and unify with overlapping shadows.
    if (overlap_next ~= nil) then
      if (overlap_prev ~= nil) then
        -- Overlaps both, so unify one and delete the other.
        overlap_prev.end_point = overlap_next.end_point
        table.remove(self.shadows, index)
      else
        -- Overlaps the next one, so unify it with that.
        overlap_next.start_point = shadow.start_point
      end
    else
      if (overlap_prev ~= nil) then
        -- Overlaps the previous one, so unify it with that.
        overlap_prev.end_point = shadow.end_point
      else
        -- Does not overlap anything, so insert.
        table.insert(self.shadows, index, shadow)
      end
    end
  end

  function Shadowline:is_full_shadow()
    return #self.shadows == 1 and self.shadows[1].start_point == 0 and self.shadows[1].end_point == 1
  end

  return Shadowline
end


function transform_octant(point, octant_number)
  -- returns altered point based on octant_number
  if octant_number == 1 then
    return {x =  point.y, y = -point.x}
  elseif octant_number == 2 then
    return {x =  point.x, y = -point.y}
  elseif octant_number == 3 then
    return {x =  point.x, y =  point.y}
  elseif octant_number == 4 then
    return {x =  point.y, y =  point.x}
  elseif octant_number == 5 then
    return {x = -point.y, y =  point.x}
  elseif octant_number == 6 then
    return {x = -point.x, y =  point.y}
  elseif octant_number == 7 then
    return {x = -point.x, y = -point.y}
  elseif octant_number == 8 then
    return {x = -point.y, y = -point.x}
  end
end


function refresh_visibility()
  for octant = 1, 8 do
    refresh_octant(game.actors.player.location, octant)
  end
end


function refresh_octant(location, octant)
  local META_LAYER = world.map[1]
  local LIGHT_LAYER = world.map[5]
  local VISIBLE = 0
  local DARK = 1

  local line = make_shadow_line()
  local full_shadow = false

  for row = 1, TILE_DISPLAY_W do
    -- Stop once we go out of bounds.
    local transformed_octant = transform_octant({x=row, y=0}, octant)
    local position = {
        x = location.x + transformed_octant.x,
        y = location.y + transformed_octant.y
      }
    if not in_world_map(position) then break end

    for col = 0, row + 1 do
      local transformed_octant = transform_octant({x=row, y=col}, octant)
      local position = {
          x = location.x + transformed_octant.x,
          y = location.y + transformed_octant.y
        }
      
      if not in_world_map(position) then break end

      if full_shadow then
        LIGHT_LAYER[position.x][position.y][1] = DARK
      else
        local projection = project_tile(row, col)

        -- Set visibilty
        local visible = not line:is_in_shadow(projection)

        if visible then
          LIGHT_LAYER[position.x][position.y][1] = VISIBLE
        else
          LIGHT_LAYER[position.x][position.y][1] = DARK
        end

        if visible and META_LAYER[position.x][position.y][1] == 1 then
          line:add(projection)
          full_shadow = line:is_full_shadow()
        end

      end -- if fullshadow else
    end -- for col
  end -- for row
end
