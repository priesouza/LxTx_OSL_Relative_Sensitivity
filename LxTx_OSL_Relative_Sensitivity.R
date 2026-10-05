### BEFORE MAKING ANY CHANGES, PLEASE REFER TO THE INSTRUCTIONS THE ACCOMPANYING "README" FILE

#---------------------------------------------------------
# CLEAR THE WORKSPACE
#---------------------------------------------------------
rm(list = ls())
graphics.off()

#---------------------------------------------------------
# SET WORKING DIRECTORY & LOAD AUXILIARY EXCEL/CSV FILE
#---------------------------------------------------------
path <- "C:/Users/Downloads/"   # inform where the working files are located

setwd(path)

input <- read.xlsx("files_info.xlsx", colNames = TRUE)
# input <- read.csv("files_info.csv", header = TRUE)

#-------------------------------------------------------------
# SPECIFY MEASUREMENT SETTINGS & SPECIFY INTEGRATION LIMITS
#-------------------------------------------------------------
t.stim <- 40              # duration (s) of light stimulation
tot.channels <- 400       # number of recorded channels

sg1 <- 1                  # channel signal integration begins at channel...
sg2 <- 10                 # signal integration ends at channel...

bg1 <- 301                # background begins at channel...
bg2 <- 400                # background ends at channel...

sti.power <- 80 * 0.9     # reader operating stimulation power
LED.wl <- 470             # LED wavelength

#-------------------------------------------------------------
# DEFINE SAR CYCLE AND SIGNAL TYPE
#-------------------------------------------------------------
n.signals <- 16           # number of signals recorded in the SAR sequence

sg.cycle <- rep(
  c("Ln", "Tn",
    "L1", "T1",
    "L2", "T2",
    "L3", "T3",
    "L4", "T4",
    "L5", "T5",
    "L6", "T6",
    "L7", "T7"),
  sum(input$n.aliquots)
)

SAR.signal <- rep(
  c("natural", "Dtest natural",
    "Regen 1", "Dtest 1",
    "Regen 2", "Dtest 2",
    "Regen 3", "Dtest 3",
    "Regen 4", "Dtest 4",
    "Regen zero", "Dtest zero",
    "Regen recy", "Dtest recy",
    "Regen pIRSL", "Dtest pIRSL"),
  sum(input$n.aliquots)
)

#-------------------------------------------------------------
# DEFINE HOW MANY COMPONENTS ARE ASSUMED FOR SIGNAL DECONVOLUTION
#-------------------------------------------------------------
components <- 3       # maximum = 4

#-------------------------------------------------------------
# DEFINE OUTPUT PREFERENCES
#-------------------------------------------------------------
output_file <- "Example_LxTx_sensitivity"

# Choose either "csv" or "xlsx"
exporting.format <- "xlsx"

# Plot results? Specify "yes" or "no"
plot.results <- "yes"

#######################################################################
###################### NOTHING ELSE TO EDIT ###########################
################ JUST PRESS CTRL+A and ENTER TO RUN ###################
#######################################################################

#-------------------------------------------------------------
# LOAD NECESSARY PACKAGES
#-------------------------------------------------------------
# install.packages(c("Luminescence", "openxlsx", "dplyr","ggplot2"))

library(Luminescence)
library(openxlsx)
library(dplyr)
library(ggplot2)

#-------------------------------------------------------------
# READING AND MERGING THE BINX FILES
#-------------------------------------------------------------
binx.files <- input$filename

data_list <- list()

for (i in binx.files) {
  
  dataset <- read_BIN2R(
    paste0(path, i)
  )
  
  data_list[[i]] <- dataset
}

data <- merge_Risoe.BINfileData(
  c(data_list),
  keep.position.number = TRUE
)

#-------------------------------------------------------------
# SELECTING OSL SIGNALS OF INTEREST
#-------------------------------------------------------------
osl.object <- subset(
  data,
  data@METADATA$TEMPERATURE == 125
)

osl.signals <- data.frame(osl.object@DATA)

#-------------------------------------------------------------
# CHECK POSITION INFORMATION
#-------------------------------------------------------------
# The number of positions must match the number of signals

if (length(osl.object@METADATA$POSITION) != ncol(osl.signals)) {
  stop("The number of POSITION values does not match the number of OSL signals.")
}

#-------------------------------------------------------------
# %BOSL1s SENSITIVITY CALCULATION
#-------------------------------------------------------------
# Initialize vectors
osl.s <- numeric(ncol(osl.signals))
bg.osl <- numeric(ncol(osl.signals))
osl.total <- numeric(ncol(osl.signals))
bg.total <- numeric(ncol(osl.signals))
sens.osl <- numeric(ncol(osl.signals))
osl <- numeric(ncol(osl.signals))

sd.bg.osl <- numeric(ncol(osl.signals))
lower.limit <- numeric(ncol(osl.signals))

# IMPORTANT:
# Start as NA, rather than as 1:length().
# Signals below the detection limit remain NA.
sens <- rep(NA_real_, ncol(osl.signals))

for (i in seq_along(osl.signals)) {
  
  # Initial OSL signal (first second)
  osl.s[i] <- sum(
    osl.signals[, i][sg1:sg2]
  )
  
  # Total OSL signal
  osl.total[i] <- sum(
    osl.signals[, i][1:bg2]
  )
  
  # Background in the first second
  bg.osl[i] <- mean(
    osl.signals[, i][bg1:bg2]
  ) * length(sg1:sg2)
  
  # Total background
  bg.total[i] <- mean(
    osl.signals[, i][bg1:bg2]
  ) * length(1:bg2)
  
  # Standard deviation of background
  sd.bg.osl[i] <- sd(
    osl.signals[, i][bg1:bg2]
  )
  
  # Lower detection limit
  lower.limit[i] <- bg.osl[i] + (3 * sd.bg.osl[i])
  
  # Net OSL signal in the first second
  osl[i] <- osl.s[i] - bg.osl[i]
  
  # %BOSL1s
  sens.osl[i] <-
    osl[i] / (osl.total[i] - bg.total[i]) * 100
  
  # Keep only signals above the detection limit
  if (osl[i] >= lower.limit[i]) {
    sens[i] <- sens.osl[i]
  }
}

#-------------------------------------------------------------
# PERFORMING SIGNAL DECONVOLUTION
#-------------------------------------------------------------
fast.prop <- numeric(ncol(osl.signals))
med.prop <- numeric(ncol(osl.signals))
slow.prop <- numeric(ncol(osl.signals))
slow.2.prop <- numeric(ncol(osl.signals))

fast <- numeric(ncol(osl.signals))
med <- numeric(ncol(osl.signals))
slow <- numeric(ncol(osl.signals))
slow.2 <- numeric(ncol(osl.signals))

data.res <- t.stim / tot.channels

t <- seq(
  data.res,
  data.res * bg2,
  data.res
)

for (i in seq_along(osl.signals)) {
  
  fit <- fit_CWCurve(
    data.frame(t, osl.signals[, i]),
    n.components.max = components,
    fit.method = "LM",
    fit.trace = FALSE,
    fit.failure_threshold = TRUE,
    LED.power = sti.power,
    LED.wavelength = LED.wl,
    plot = FALSE
  )
  
  
  #-----------------------------------------------------------
  # FOUR COMPONENTS
  #-----------------------------------------------------------
  if (ncol(fit$component.contribution.matrix[[1]]) == 15) {
    
    denominator <-
      sum(fit$component.contribution.matrix[[1]][, "cont.c1"][sg1:sg2]) +
      sum(fit$component.contribution.matrix[[1]][, "cont.c2"][sg1:sg2]) +
      sum(fit$component.contribution.matrix[[1]][, "cont.c3"][sg1:sg2]) +
      sum(fit$component.contribution.matrix[[1]][, "cont.c4"][sg1:sg2])
    
    fast.prop[i] <-
      sum(fit$component.contribution.matrix[[1]][, "cont.c1"][sg1:sg2]) /
      denominator * 100
    
    med.prop[i] <-
      sum(fit$component.contribution.matrix[[1]][, "cont.c2"][sg1:sg2]) /
      denominator * 100
    
    slow.prop[i] <-
      sum(fit$component.contribution.matrix[[1]][, "cont.c3"][sg1:sg2]) /
      denominator * 100
    
    slow.2.prop[i] <-
      sum(fit$component.contribution.matrix[[1]][, "cont.c4"][sg1:sg2]) /
      denominator * 100
    
    fast[i] <-
      data.frame(
        fit$component.contribution.matrix[[1]][, "cont.c1"]
      )
    
    med[i] <-
      data.frame(
        fit$component.contribution.matrix[[1]][, "cont.c2"]
      )
    
    slow[i] <-
      data.frame(
        fit$component.contribution.matrix[[1]][, "cont.c3"]
      )
    
    slow.2[i] <-
      data.frame(
        fit$component.contribution.matrix[[1]][, "cont.c4"]
      )
  }
  
  #-----------------------------------------------------------
  # THREE COMPONENTS
  #-----------------------------------------------------------
  if (ncol(fit$component.contribution.matrix[[1]]) == 12) {
    
    denominator <-
      sum(fit$component.contribution.matrix[[1]][, "cont.c1"][sg1:sg2]) +
      sum(fit$component.contribution.matrix[[1]][, "cont.c2"][sg1:sg2]) +
      sum(fit$component.contribution.matrix[[1]][, "cont.c3"][sg1:sg2])
    
    fast.prop[i] <-
      sum(fit$component.contribution.matrix[[1]][, "cont.c1"][sg1:sg2]) /
      denominator * 100
    
    med.prop[i] <-
      sum(fit$component.contribution.matrix[[1]][, "cont.c2"][sg1:sg2]) /
      denominator * 100
    
    slow.prop[i] <-
      sum(fit$component.contribution.matrix[[1]][, "cont.c3"][sg1:sg2]) /
      denominator * 100
    
    slow.2.prop[i] <- NA_real_
    
    fast[i] <-
      data.frame(
        fit$component.contribution.matrix[[1]][, "cont.c1"]
      )
    
    med[i] <-
      data.frame(
        fit$component.contribution.matrix[[1]][, "cont.c2"]
      )
    
    slow[i] <-
      data.frame(
        fit$component.contribution.matrix[[1]][, "cont.c3"]
      )
    
    slow.2[i] <- NA_real_
  }
  
  #-----------------------------------------------------------
  # TWO COMPONENTS
  #-----------------------------------------------------------
  if (ncol(fit$component.contribution.matrix[[1]]) == 9) {
    
    denominator <-
      sum(fit$component.contribution.matrix[[1]][, "cont.c1"][sg1:sg2]) +
      sum(fit$component.contribution.matrix[[1]][, "cont.c2"][sg1:sg2])
    
    fast.prop[i] <-
      sum(fit$component.contribution.matrix[[1]][, "cont.c1"][sg1:sg2]) /
      denominator * 100
    
    med.prop[i] <-
      sum(fit$component.contribution.matrix[[1]][, "cont.c2"][sg1:sg2]) /
      denominator * 100
    
    slow.prop[i] <- NA_real_
    slow.2.prop[i] <- NA_real_
    
    fast[i] <-
      data.frame(
        fit$component.contribution.matrix[[1]][, "cont.c1"]
      )
    
    med[i] <-
      data.frame(
        fit$component.contribution.matrix[[1]][, "cont.c2"]
      )
    
    slow[i] <- NA_real_
    slow.2[i] <- NA_real_
  }
  
  #-----------------------------------------------------------
  # ONE COMPONENT
  #-----------------------------------------------------------
  if (ncol(fit$component.contribution.matrix[[1]]) == 6) {
    
    fast.prop[i] <- 100
    
    med.prop[i] <- NA_real_
    slow.prop[i] <- NA_real_
    slow.2.prop[i] <- NA_real_
    
    fast[i] <-
      data.frame(
        fit$component.contribution.matrix[[1]][, "cont.c1"]
      )
    
    med[i] <- NA_real_
    slow[i] <- NA_real_
    slow.2[i] <- NA_real_
  }
}

#-------------------------------------------------------------
# CONDENSING THE RESULTS BY ALIQUOT
#-------------------------------------------------------------
# Sample names
sample.id <- rep(
  input$sample,
  n.signals * input$n.aliquots
)

# IMPORTANT:
# Use the original physical position stored in the BINX file
aliquot <- osl.object@METADATA$POSITION

# Check that all vectors have the same length
if (length(aliquot) != length(sens) ||
    length(aliquot) != length(sample.id) ||
    length(aliquot) != length(sg.cycle) ||
    length(aliquot) != length(SAR.signal)) {
  
  stop("The result vectors do not have the same length.")
}

# Create results table
results <- data.frame(
  aliquot = aliquot,
  sample = sample.id,
  `SAR cycle` = sg.cycle,
  `SAR signal` = SAR.signal,
  `%BOSLf` = sens,
  `fast (% of BOSLf)` = fast.prop,
  `medium (% of BOSLf)` = med.prop,
  `slow (% of BOSLf)` = slow.prop,
  check.names = FALSE
)

View(results)

#-------------------------------------------------------------
# CONDENSING THE RESULTS BY SAMPLE
#-------------------------------------------------------------
statistics <- results %>%
  group_by(
    sample,
    `SAR cycle`,`SAR signal`
  ) %>%
  summarise(
    n = sum(!is.na(`%BOSLf`)),
    mean = mean(`%BOSLf`, na.rm = TRUE),
    SD = sd(`%BOSLf`, na.rm = TRUE),
    SE = SD / sqrt(n),
    median = median(`%BOSLf`, na.rm = TRUE),
    .groups = "drop"
  )

View(statistics)

#-------------------------------------------------------------
# PLOTTING RESULTS
#-------------------------------------------------------------
if (plot.results == "yes") {
  
  samples <- unique(results$sample)
  
  for (s in samples) {
    
    plot.data <- results %>%
      filter(sample == s)
    
    p <- ggplot(
      plot.data,
      aes(
        x = `SAR cycle`,
        y = `%BOSLf`
      )
    ) +
      geom_boxplot(
        na.rm = TRUE
      ) +
      scale_y_continuous(
        limits = c(0, 100)
      ) +
      labs(
        title = paste("Sample:", s),
        x = "SAR cycle",
        y = "%BOSL1s"
      ) +
      theme_classic() +
      theme(
        axis.text.x = element_text(
          angle = 45,
          hjust = 1
        )
      )
    
    print(p)
    
    ggsave(
      filename = paste0(
        path,
        output_file,
        "_",
        s,
        "_boxplot.png"
      ),
      plot = p,
      width = 10,
      height = 6,
      dpi = 300
    )
  }
}

#-------------------------------------------------------------
# EXPORTING RESULTS
#-------------------------------------------------------------

if (exporting.format == "csv") {
  
  # Results for each aliquot
  write.csv(
    results,
    file = paste0(
      path,
      output_file,
      "_by_aliquot.csv"
    ),
    row.names = FALSE
  )
  
  
  # Statistics by sample
  write.csv(
    statistics,
    file = paste0(
      path,
      output_file,
      "_by_sample.csv"
    ),
    row.names = FALSE
  )
  
} else {
  
  # One Excel file with two sheets
  write.xlsx(
    list(
      by_aliquot = results,
      by_sample = statistics
    ),
    file = paste0(
      path,
      output_file,
      ".xlsx"
    ),
    rowNames = FALSE
  )
}