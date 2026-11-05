local addonName, ns = ...

-- Which client this build is running on. This file is loaded right after the locales and before
-- the theme, so every gate in the addon sees the flag by the time it runs.
--
-- Forever is the 12.1 engine with a 1.60 interface number: retail reports 12xxxx, Classic Era
-- 115xx, and the ranges never meet. That is the only test that holds -- WOW_PROJECT_ID cannot
-- tell Forever apart from retail, since the early betas still answered MAINLINE.
--
-- The Lua harness slices these files and has no client, so the fallback keeps every gate on the
-- retail path there.
local build
if GetBuildInfo then build = select(4, GetBuildInfo()) end
build = tonumber(build) or 120105

ns.build = build
ns.IsForever = build >= 16000 and build < 20000
ns.IsRetail = not ns.IsForever

-- The options pages hang a row on this: a switch for a system the client does not have is worse than no
-- switch, because it reads as broken rather than as absent. Passed as `hidden = ns.ForeverOnly`.
function ns.ForeverOnly()
  return ns.IsForever
end
