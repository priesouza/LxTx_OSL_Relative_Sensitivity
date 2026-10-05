# Quartz BOSL relative sensitivity of Lx and Tx signals

## Scope and intended use

This R routine is designed to derive quartz sensitivity data from luminescence signals stimulated with blue LEDs at 125 °C (BOSL<sub>125</sub>), recorded over SAR OSL dating sequences.
It is intended for researchers working with quartz OSL data who wish to reuse data acquired during OSL dating (stored as .binx files) for sediment provenance analysis, potentially avoiding additional sampling or measurements when the required data are already available.

Here, relative sensitivity values are calculated for all BOSL<sub>125</sub> signals recorded in more than one .binx file.

This code accompanies the paper:

> Souza, P. E., Porat, N., Sawakuchi, A. O., Cruz, C. B. L., Breda, C., Rodrigues, F. C. G., ... & Pupim, F. N. (2024). Using quartz OSL signals from SAR cycles for sediment provenance studies. Quaternary Geochronology, 83, 101574.

## Methodology

The calculations implemented in this script follow the methodology described in Souza et al., 2024 (https://doi.org/10.1016/j.quageo.2024.101574):

- All BOSL signals measured at 125 °C in the SAR OSL dating sequences are analysed. As default, the script assumes input .binx files with eight SAR cycles, but it can be edited.
- %BOSL<sub>1s</sub> is calculated as the ratio between the net signal integrated over the first second of BOSL stimulation and the net signal integrated over the full stimulation time.
- Net signals are calculated using a late-background subtraction, with the background estimated from the last 10 s of the BOSL signal.
- CW-OSL signal deconvolution is performed using the `fit_CWCurve()` function (Kreutzer, 2020), available in the `Luminescence` R package.

## What it does

- Reads quartz OSL signals from more than one `.binx` file (Risø TL/OSL reader format) measured in the same manner (i.e., with identical settings)
- Calculates %BOSL<sub>1s</sub> sensitivity (ratio of the fast OSL component to the total OSL signal), filtering out aliquots below a background threshold ("dim" aliquots)
- Deconvolutes the CW-OSL decay curve into fast, medium, and slow components using `Luminescence::fit_CWCurve()`
- Exports per-aliquot results (sensitivity values and component proportions) to Excel or CSV
- Exports per-sample %BOSL<sub>1s</sub> results (n, mean, SD, SE, median) to Excel or CSV
- Plots %BOSL<sub>1s</sub> results per-signal (one plot per sample).

## Requirements

- R (>= 4.0.0)
- Required packages:
  ```r
  install.packages(c("Luminescence", "openxlsx", "dplyr","ggplot2"))
  ```

## Installation

Clone this repository:

```bash
git clone https://github.com/priesouza/LxTx_OSL_Relative_Sensitivity.git
cd LxTx_OSL_Relative_Sensitivity
```

## Usage

This script is not organized as a callable function — it is meant to be edited and run as a whole.

1. Open `LxTx_OSL_Relative_Sensitivity.R` in RStudio.
2. Edit the parameters at the top of the script (lines 12–77) to match your data, settings, and your preferences:
  
   - `path`: folder containing the `.binx` files and the auxiliary file named "files.info"
   - `input`: auxiliary file containing a list of .binx files that will be analysed and additional information about each .binx file 
   - `t.stim`, `tot.channels`, `sg1`, `sg2`, `bg1`, `bg2`: stimulation and channel/background integration settings
   - `sti.power`, `LED.wl`: reader stimulation power and LED wavelength
   - `n.signals`: number of OSL signals stimulated at 125 °C
   - `sg.cycle`: short label for each signal being analysed 
   - `SAR.signal`: descriptive label for each signal being analysed
   - `components`: number of components assumed for signal deconvolution (1–4)
   - `output_file`: name of the output file (without extension)
   - `exporting.format`: `"Excel"` or `"csv"`
   - `plot.results`: `"yes"` or `"no"`

    IMPORTANT: As default, the script is set for a SAR sequence with eight cycles (16 signals of interest), as follows:
   - the first cycle with the natural dose (signals Ln and Tn)
   - four cycles with regenerative doses (L1, T1, L2, T2, L3, T3, L4, T4)
   - three cycles with regenerative doses for internal performance tests: recuperation test (L5,T5), recycling test(L6, T6), and IR depletion ratio (L7, T7).
   
   In case the user's sequences have more/less eight SAR cycles, `sg.cycle` and `SAR.signal` in the section "DEFINE SAR CYCLE AND SIGNAL TYPE" must be edited accordingly. 
  
4. Select the entire script (Ctrl+A) and run it (Ctrl+Enter / Ctrl+R), as noted in the script's own comments.
5. The script reads the `.binx` file, calculates %BOSL<sub>1s</sub> sensitivity, performs CW-OSL curve deconvolution (via the `Luminescence` package), plots the results (optional), and exports the results.


### Input

1. Auxiliary file "files.info" (.csv or .xlsx format) 
2. More than one single-aliquot regenerative-dose (SAR) `.binx` file (Risø reader format), read via `Luminescence::read_BIN2R()`.

   IMPORTANT: Input files must be located in the same folder ("working directory") and must have been acquired using the same measurement settings. This means that:
   - the sequences must have been run in the same luminescence reader
   - the sequences must have been run horizontally ("one at a time")
   - treatments (preheating, dosing, stimulation, etc.) must have been performed in the same order
   - the number of SAR cycles must be the same
   - the data resolution must be the same (e.g., "OSL cts per 0.1s")

### Output

An Excel file (.xlsx, with two sheets) or two CSV files containing:

1. **Per aliquot:**
   - Sample and aliquot identification (aliquot position, sample ID, SAR cycle, and SAR signal)
   - %BOSL<sub>1s</sub> sensitivity values
   - Relative proportions of fast-, medium-, and slow-decaying components obtained by signal deconvolution

2. **Per sample:**
   - Sample and signal identification (sample ID and SAR cycle)
   - %BOSL<sub>1s</sub> sensitivity statistics for each signal, including *n*, mean, standard deviation, standard error, and median


Additionally, and optionally, the results can be visualized as boxplots. One plot is generated for each sample, with a separate boxplot for each SAR signal.

The output file(s) are saved using the name specified in `output_file`.

## Example

This script ship with an example dataset. To test it, use the files:
 - `files.info.csv` or `files.info.xlsx`
 - `EXAMPLE(1)_Quartz_OSL_dating.binx`
 - `EXAMPLE(2)_Quartz_OSL_dating.binx`

IMPORTANT: these files must be in the same directory, as specified in line 12 (`path`) 

## Repository structure

```
├── LxTx_OSL_Relative_Sensitivity.R   # Main script
├── files.info.csv # Example of auxiliary file (.csv format) to test the script 
├── files.info.xlsx # Example of auxiliary file (.xlsx format) to test the script
├── EXAMPLE(1)_Quartz_OSL_dating.binx # Example #1 file to test the script
├── EXAMPLE(2)_Quartz_OSL_dating.binx # Example #2 file to test the script
├── README.md
├── CITATION.cff
└── LICENSE
```

## Citation

If you use this script in your research, please cite both the paper and the software itself (see `CITATION.cff`, or the "Cite this repository" button on GitHub).

## License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.

## Contact

Priscila E. Souza
Departamento de Geografia Física, Faculdade de Filosofia, Letras e Ciências Humanas, Universidade de São Paulo
[pesouza@usp.br]
[https://orcid.org/0000-0001-9975-2074]
