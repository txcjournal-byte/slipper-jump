--!strict
-- Registr služeb: Main.server.luau sem uloží všechny služby, aby se mohly volat navzájem
-- bez cyklických require().

local Registry: { [string]: any } = {}

return Registry
