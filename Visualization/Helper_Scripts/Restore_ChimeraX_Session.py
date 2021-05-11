from chimerax.atomic import Structure
from chimerax.core.commands import run

run(session,"view")

for m in session.models:
	if isinstance(m, Structure):
		m._set_chain_descriptions(session)
		m._report_chain_descriptions(session)