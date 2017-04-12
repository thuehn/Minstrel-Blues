#!/usr/bin/env Rscript
args = commandArgs(trailingOnly=TRUE)
if ( length ( args ) == 0 ) {
    stop ( "At least one argument must be supplied (input file).\n", call.=FALSE )
}
#filename = read.table ( args[1], header=TRUE )
#print ( args[1] )
#print ( filename )
filename = args [1]
print ( filename )

snrs <- scan ( filename )
snrs <- c ( snrs )

# Give the chart file a name.
pngfilename = paste ( filename, "png", sep = ".")
png ( file = pngfilename )

# Plot the bar chart.
plot ( snrs, type = "o", col = "red", xlab = "power", ylab = "SNR",
        main = filename)

# Save the file.
dev.off()
