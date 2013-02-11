kbws-url "http://localhost:7058"
kbws-login kbasetest -p "@Suite525"
kbws-workspace default
kbws-deletews scripttest n
kbws-createws scripttest n
kbws-workspace scripttest
kbfba-url "http://localhost:7036"
kbfba-loadgenome "kb|g.0" -e
kbfba-buildfbamodel "kb|g.0" -m "kb|g.0.fbamdl.201" -e
kbfba-runfba "kb|g.0.fbamdl.201" -e
kbfba-addmedia GlucoseMinimal "D-Glucose;Sulfate;Phosphate;NH3;Al;Boron;Ca2+;Cl-;Co2+;Cu2+;Fe2+;Fe3+;H+;H2O;K+;Mg;Mn2+;Ni2+;Molybdate;Na+;O2;Zn2+" -d -type "Minimal"
#Gapfilling jobs run a long time and consume our cluster, which is busy doing work for the demo: I'm cutting this test for now. We need a test that makes a very fast gapfilling job. I know how to do this, but it will take time to develop the test.
#kbfba-gapfill "kb|g.0.fbamdl.201" -e
#kbfba-gapfill "kb|g.0.fbamdl.201" -m "GlucoseMinimal" --mediaws "scripttest" -e
#kbfba-gapgen "kb|g.0.fbamdl.201" -r myMedia --refmediaws scripttest
