from chimerax.atomic import Structure
from chimerax.core.commands import run

run(session,"color byattribute bfactor palette orangered:yellow:cyan:blue range 50,100 key true")
run(session,"key pos 0.45,0.1 size 0.5,0.06 justification left labelOffset 5")
run(session,"view")