ws-url dev
kbase-login kbasetest -p "@Suite525"
ws-workspace scripttest
fba-url "http://localhost:7036"
fba-loadgenome "kb|g.0" -e
fba-loadgenome "315750.3" -r -l reviewer -p reviewer -e
fba-buildfbamodel "kb|g.0" -m "testmodel" --core -e
fba-runfba "testmodel" -e
fba-addmedia GlucoseMinimal "D-Glucose;Sulfate;Phosphate;NH3;Al;Boron;Ca2+;Cl-;Co2+;Cu2+;Fe2+;Fe3+;H+;H2O;K+;Mg;Mn2+;Ni2+;Molybdate;Na+;O2;Zn2+" -d -type "Minimal"