# keggerator v1.1
**Guided computational metabolic reconstruction using orthology.**

## Description
`keggerator` is a suite of tools designed to aid in the computational reconstruction of metabolic pathways from genomic data. It uses orthology to transfer metabolic assignments from Kyoto Encyclopedia of Genes and Genomes (KEGG) across related organisms.


## Attribution
`keggerator` was written by [Timothy Driscoll](http://www.driscollMML.com/) at West Virginia University, Morgantown, WV USA, with much help and input from Joseph J. Gillespie at University of Maryland and Victoria Verhoeve at West Virginia University. If you use this code in your research, please cite our original research article: [Driscoll et al. "Wholly *Rickettsia*! Reconstructed metabolic profile for the quintessential bacterial parasite of eukaryotic cells." *mBio* X(X):XX-XX](http://??/).


## Installation
Please see the INSTALL.md file included in the top-level **keggerator/** directory.



## Usage
`keggerator` is designed as a pipeline and can be run in several ways. In general, however, it all starts with the following three steps:

1. Assemble a single *.fasta* file containing all of the protein sequences that you want to analyze.
2. Submit these sequences as query to KEGG using [BlastKOALA](http://www.kegg.jp/blastkoala/), KEGG's annotation tool for assigning K numbers. In many cases, you will have to run your sequences in multiple batches thanks to the input limits in BlastKOALA. When the KEGG analysis is complete, you will receive an email with a link to the results. The results will include three different html files: one for KEGG pathways, one for KEGG modules, and one for KEGG brite entries. **Download these html files** into separate directories, as demonstrated in **keggerator/demo/**. If you had to run BlastKOALA in batches, you will have multiple html files in each directory.
3. Use your fasta sequences to construct ortholog groups using [OrthoMCL](http://orthomcl.org/orthomcl/) and download the result file (*.end*). Each line in this file contains all the protein ids and taxa in a single ortholog group; see the corresponding file in **keggerator/demo/** for an example.


#### METHOD THE FIRST:
###### QuickStart
Run the `keggerator` wrapper script, passing it the three inputs described above and an (optional) output name string:

`keggerator -f FA_FILE -g ORTH_FILE (-p PWAY_DIR &| -m MODULE_DIR &| -b BRITE_DIR) [-o OUTBASE]`

Run in this way, the wrapper script calls the three `keggerator` component programs sequentially (see "Method the Second" below for details). It produces a final table showing the presence/absence of each metabolic component in each input genome, as shown in Supplementary Figure S10 in [Driscoll et al. "Wholly *Rickettsia*! Reconstructed metabolic profile for the quintessential bacterial parasite of eukaryotic cells." *mBio* X(X):XX-XX](http://??/).

###### CustomStart

`keggerator` accepts several optional arguments that you can use to customize your results. A complete list can be found by running `keggerator -h`.

`keggerator -f FA_FILE -g ORTH_FILE (-p PWAY_DIR &| -m MODULE_DIR &| -b BRITE_DIR) [-t TAXON_FILE] [-k KNUM_FILE || STRING] [-o OUTBASE]`

> ##### -f \<*filepath*\>
> REQUIRED
> Path to the original **protein fasta file** containing the query sequences.

> ##### -g \<*filepath*\>
> REQUIRED
> Path to the **orthology file (*.end*)** created from running the original protein sequences through orthoMCL or OGRE.

> ##### -p \<*dirpath*\>
> REQUIRED (at least one of -p, -m, or -b)
> Path to a directory containing **KEGG pathway output *.html* files**, created by running the original protein sequences through BlastKOALA.

> ##### -m \<*dirpath*\>
> REQUIRED (at least one of -p, -m, or -b)
> Path to a directory containing **KEGG module output *.html* files**, created by running the original protein sequences through BlastKOALA.

> ##### -b \<*dirpath*\>
> REQUIRED (at least one of -p, -m, or -b)
> Path to a directory containing **KEGG brite output *.html* files**, created by running the original protein sequences through BlastKOALA.

> ##### -t \<*filepath*\>
> OPTIONAL
> Path to an ordered list of taxa  (one taxon string per line) to use in sorting the output grid. Taxon names must match those in the protein fasta and orthology files exactly. [default: alphabetical, derived from the protein fasta file.]

> ##### -k \<*filepath* or *string*\>
> OPTIONAL
> Path to a file containing the K numbers to include in the final grid, or one of a set of pre-built sets [default: glycolysis]. The file must have each K number on a separate line. It may also include locus tags and associated pathway/group names in tab-delimited format. See any of the files in **keggerator/sbin/ksets/** for the accepted syntax.
> Accepted *string* arguments to -k are (case-insensitive):
> biotin, fattyacids, folate, glycerophospholipids, heme, lipopolysaccharide, nucleotides, peptidoglycan, queosine, tca, ubiquinone
> 
> ##### -o \<*string*\>
> OPTIONAL
> String to use as the prefix to **project output** file names [default: keggerator.grid.txt].


#### METHOD THE SECOND:
You can also run the *keggerator* program scripts separately. There are four, located alongside the `keggerator` script in **keggerator/sbin/**:

1. `kcompile` requires as minimum input the original protein fasta file used to query BlastKOALA, and any BlastKOALA output html files (brite, pathway, and/or module). It constructs a master table assigning annotations and metabolic classifications ("KO numbers") to all possible proteins.
2. `ktransfer` requires as minimum input the kcompile table from step 1, and the orthology file (.end) described above. It transfers metabolic assignments from individual proteins to their component ortholog groups.
3. `kreconstruct` requires as minimum input the original protein fasta and orthology files, plus the output file from `ktransfer`. It creates a table showing the presence/absence of each metabolic component in each input genome. Optional arguments include a file of taxon names in sort order, and a file of K numbers to reconstruct.

For detailed instructions and all accepted arguments, simply run any program script with the -h flag; for example:
`kcompile -h`


## License
*keggerator* is released under the GNU GPL v3 license. Please see the LICENSE file included in the top-level **keggerator** directory.
