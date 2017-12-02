# RELEASE LOG
### keggerator v1.1
[https://github.com/driscollmml/keggerator](https://github.com/driscollmml/keggerator)

## VERSION 1.1
**RELEASE DATE:** December 1, 2017
**DESCRIPTION:** keggerator v1.1 fixes several significant bugs in kreconstruct. ORPHAN orthologs are now ignored instead of throwing an error. the final output table has been renamed to [OUTBASE].FINAL.table.txt, and the columns are sorted according to the K number input order, not numerically by OG. Finally, K numbers in the input that have no corresponding OG are shown as empty columns in the final output.
**KNOWN LIMITATIONS:** Same as for v1.0.


## VERSION 1.0
**RELEASE DATE:** August 10, 2017
**DESCRIPTION:** keggerator v1.0 is the first fully-functional, soup-to-nuts release. It has been tested using 84 sequenced Rickettsia genomes, as described in the original research article [Driscoll et al. (2017) *mBio* 8(5):e00859-17](http://mbio.asm.org/content/8/5/e00859-17.full).
**KNOWN LIMITATIONS:** Orthology and BlastKOALA data must be generated before running keggerator. Also, only orthoMCL- or ogre-formatted .end files are accepted.

