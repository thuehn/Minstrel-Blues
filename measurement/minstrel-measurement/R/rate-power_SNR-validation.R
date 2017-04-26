#!/usr/bin/env Rscript

library(ggplot2)
library(scales)
library(readr)
library(tidyverse)
library(plotly)
library(Hmisc)
library(quantreg)

#mapping of MCS/bw/stream/Guardinterval descriptions to coresponding rate_idx
rate_idx <- c(
    `0`   = "MCS 0, HT20, LGI, ss:1",
    `1`   = "MCS 1, HT20, LGI, ss:1",
    `2`   = "MCS 2, HT20, LGI, ss:1",
    `3`   = "MCS 3, HT20, LGI, ss:1",
    `4`   = "MCS 4, HT20, LGI, ss:1",
    `5`   = "MCS 5, HT20, LGI, ss:1",
    `6`   = "MCS 6, HT20, LGI, ss:1",
    `7`   = "MCS 7, HT20, LGI, ss:1",
    `10`  = "MCS 8, HT20, LGI, ss:2",
    `11`  = "MCS 9, HT20, LGI, ss:2",
    `12`  = "MCS 10, HT20, LGI, ss:2",
    `13`  = "MCS 11, HT20, LGI, ss:2",
    `14`  = "MCS 12, HT20, LGI, ss:2",
    `15`  = "MCS 13, HT20, LGI, ss:2",
    `16`  = "MCS 14, HT20, LGI, ss:2",
    `17`  = "MCS 15, HT20, LGI, ss:2",
    `20`  = "MCS 16, HT20, LGI, ss:3",
    `21`  = "MCS 17, HT20, LGI, ss:3",
    `22`  = "MCS 18, HT20, LGI, ss:3",
    `23`  = "MCS 19, HT20, LGI, ss:3",
    `24`  = "MCS 20, HT20, LGI, ss:3",
    `25`  = "MCS 21, HT20, LGI, ss:3",
    `26`  = "MCS 22, HT20, LGI, ss:3",
    `27`  = "MCS 23, HT20, LGI, ss:3",
    `30`  = "MCS 0, HT20, SGI, ss:1",
    `31`  = "MCS 1, HT20, SGI, ss:1",
    `32`  = "MCS 2, HT20, SGI, ss:1",
    `33`  = "MCS 3, HT20, SGI, ss:1",
    `34`  = "MCS 4, HT20, SGI, ss:1",
    `35`  = "MCS 5, HT20, SGI, ss:1",
    `36`  = "MCS 6, HT20, SGI, ss:1",
    `37`  = "MCS 7, HT20, SGI, ss:1",
    `40`  = "MCS 8, HT20, SGI, ss:2",
    `41`  = "MCS 9, HT20, SGI, ss:2",
    `42`  = "MCS 10, HT20, SGI, ss:2",
    `43`  = "MCS 11, HT20, SGI, ss:2",
    `44`  = "MCS 12, HT20, SGI, ss:2",
    `45`  = "MCS 13, HT20, SGI, ss:2",
    `46`  = "MCS 14, HT20, SGI, ss:2",
    `47`  = "MCS 15, HT20, SGI, ss:2",
    `50`  = "MCS 16, HT20, SGI, ss:3",
    `51`  = "MCS 17, HT20, SGI, ss:3",
    `52`  = "MCS 18, HT20, SGI, ss:3",
    `53`  = "MCS 19, HT20, SGI, ss:3",
    `54`  = "MCS 20, HT20, SGI, ss:3",
    `55`  = "MCS 21, HT20, SGI, ss:3",
    `56`  = "MCS 22, HT20, SGI, ss:3",
    `57`  = "MCS 23, HT20, SGI, ss:3",
    `60`  = "MCS 0, HT40, LGI, ss:1",
    `61`  = "MCS 1, HT40, LGI, ss:1",
    `62`  = "MCS 2, HT40, LGI, ss:1",
    `63`  = "MCS 3, HT40, LGI, ss:1",
    `64`  = "MCS 4, HT40, LGI, ss:1",
    `65`  = "MCS 5, HT40, LGI, ss:1",
    `66`  = "MCS 6, HT40, LGI, ss:1",
    `67`  = "MCS 7, HT40, LGI, ss:1",
    `70`  = "MCS 8, HT40, LGI, ss:2",
    `71`  = "MCS 9, HT40, LGI, ss:2",
    `72`  = "MCS 10, HT40, LGI, ss:2",
    `73`  = "MCS 11, HT40, LGI, ss:2",
    `74`  = "MCS 12, HT40, LGI, ss:2",
    `75`  = "MCS 13, HT40, LGI, ss:2",
    `76`  = "MCS 14, HT40, LGI, ss:2",
    `77`  = "MCS 15, HT40, LGI, ss:2",
    `80`  = "MCS 16, HT40, LGI, ss:3",
    `81`  = "MCS 17, HT40, LGI, ss:3",
    `82`  = "MCS 18, HT40, LGI, ss:3",
    `83`  = "MCS 19, HT40, LGI, ss:3",
    `84`  = "MCS 20, HT40, LGI, ss:3",
    `85`  = "MCS 21, HT40, LGI, ss:3",
    `86`  = "MCS 22, HT40, LGI, ss:3",
    `87`  = "MCS 23, HT40, LGI, ss:3",
    `90`  = "MCS 0, HT40, SGI, ss:1",
    `91`  = "MCS 1, HT40, SGI, ss:1",
    `92`  = "MCS 2, HT40, SGI, ss:1",
    `93`  = "MCS 3, HT40, SGI, ss:1",
    `94`  = "MCS 4, HT40, SGI, ss:1",
    `95`  = "MCS 5, HT40, SGI, ss:1",
    `96`  = "MCS 6, HT40, SGI, ss:1",
    `97`  = "MCS 7, HT40, SGI, ss:1",
    `100` = "MCS 8, HT40, SGI, ss:2",
    `101` = "MCS 9, HT40, SGI, ss:2",
    `102` = "MCS 10, HT40, SGI, ss:2",
    `103` = "MCS 11, HT40, SGI, ss:2",
    `104` = "MCS 12, HT40, SGI, ss:2",
    `105` = "MCS 13, HT40, SGI, ss:2",
    `106` = "MCS 14, HT40, SGI, ss:2",
    `107` = "MCS 15, HT40, SGI, ss:2",
    `110` = "MCS 16, HT40, SGI, ss:3",
    `111` = "MCS 17, HT40, SGI, ss:3",
    `112` = "MCS 18, HT40, SGI, ss:3",
    `113` = "MCS 19, HT40, SGI, ss:3",
    `114` = "MCS 20, HT40, SGI, ss:3",
    `115` = "MCS 21, HT40, SGI, ss:3",
    `116` = "MCS 22, HT40, SGI, ss:3",
    `117` = "MCS 23, HT40, SGI, ss:3"
)

args = commandArgs(trailingOnly=TRUE)
if ( length ( args ) < 2 ) {
    stop ( "At least two arguments must be supplied (input file, wifi_config).\n", call.=FALSE )
}
workingdir = args [1]
print ( workingdir )
# set working directory
setwd(workingdir)

wifi_config_file = args [2]
print ( wifi_config_file )
wifi_config = read_delim ( wifi_config_file, col_names = FALSE, delim="=", col_types = "cc")

channel <- trimws ( wifi_config [1, 2] )
htmode <- trimws ( wifi_config [2, 2] )
distance <- trimws ( wifi_config [3, 2] )

#read our snr data
# rate power weighted_snr count
snr_raw <- read_delim("snr-histogram-per_rate-power.csv", col_names = TRUE, delim=" ", col_types = "iiii")

#remove measurement errors of snr outliers when 30dB is max txpower value range
#snr <- snr %>% filter(snr > (max(snr) - 30))

#respect current max txpower supported by the hardware, so remove power levels > 21 dBm
snr <- snr_raw %>% filter(txpower < 22)

#add weighted mean for each rate/power combination
snr <- snr %>%
        group_by(txrate,txpower) %>%
        mutate(weighted_snr = weighted.mean(snr,count))

#add maximum & minimum of weighted_snr to each txrate group
snr <- snr %>%
        group_by(txrate) %>%
        arrange(txrate,txpower) %>%
        mutate(max_snr = max(weighted_snr)) %>%
        mutate(min_snr = min(weighted_snr))

#mean snr for each txrate & txpower combination
mean_snr <- snr %>%
    group_by(txrate,txpower,weighted_snr) %>%
    summarise()

#save as csv
write.csv(mean_snr, file = "mean_snr.csv")

textsize = 8
titlesize = 20
legendtitlesize = 10
legendtextsize = 8
axistitlesize = 14
legendmargin = 10
axismarginH = 10

txpowerscale = 3
txpowercount = length ( seq ( min ( snr$txpower ) , max ( snr$txpower ) ) )
if ( txpowercount > 25 ) { txpowerscale = 5 }
if ( txpowercount > 40 ) { txpowerscale = 10 }

snrscale = 3
snrcount = length ( seq ( min ( snr$snr ) , max ( snr$snr ) ) )
if ( snrcount > 20 ) { snrscale = 5 }
if ( snrcount > 30 ) { snrscale = 10 }
if ( snrcount > 40 ) { snrscale = 15 }

#single plot per rate_idx in facet_wrap
plot_snr_1 <- ggplot(data = snr, aes(x = txpower, y = snr, weight = count/sum(as.numeric(count)))) +
    geom_point(size=0.4, alpha=0.6) +
    stat_summary(fun.data = "mean_cl_boot", geom = "crossbar", colour = "red", width = 0.5, alpha=0.4) +
    geom_smooth(aes(colour=as.factor(txrate%%10)), stat = "smooth", method = "loess", size = 0.8, alpha=0.5) +
    scale_x_continuous(breaks = seq(min(snr$txpower), max(snr$txpower), by = txpowerscale)) +
    scale_y_continuous(breaks = seq(min(snr$snr), max(snr$snr), by = snrscale)) +
    labs(x = "Adjusted TX-Power at Transmitter [dBm]", y = "Measured SNR at Receiver [dB]") +
    theme_bw() +
    labs(title = "Validation of Transmit Power Control Using ath9k on Atheros AR9344",
         subtitle=sprintf("Boxplot of Measured SNR as Function of TX-Rate and TX-Power, Channel %s %s and Distance %s",
                          channel, htmode, distance)) +
    theme(strip.text = element_text(size=textsize),
          strip.text.x = element_text(size=textsize),
          strip.text.y = element_text(size=textsize),
          axis.text.x = element_text(angle = 0, size = textsize, colour = "black"),
          axis.text.y = element_text(size = textsize, colour = "black"),
          plot.title=element_text(colour="black", face="plain", size=titlesize, margin = margin(10, 0, 10, 0)),
          strip.background = element_rect(colour='grey30', fill='grey80'),
          legend.title=element_text(colour="black", size=legendtitlesize, margin = margin(l = legendmargin), face="plain"),
          legend.text=element_text(colour="black", size=legendtextsize, face="plain"),
          legend.background = element_rect(),
          legend.position = "bottom",
          axis.title.y = element_text(angle = 90, size = axistitlesize, colour = "black", face="plain", margin = margin(r = axismarginH)),
          axis.title.x = element_text(angle = 0, size = axistitlesize, colour = "black", face="plain", margin = margin(t = 15))
    ) +
    scale_colour_brewer(name = "MCS % 8", palette = "PRGn") +
    facet_wrap(~ txrate, ncol = 8, labeller = as_labeller(rate_idx))

#save plot
ggsave(plot_snr_1, file="snr_per_rate-power_v1.png", width=11, height=8, dpi=600)

#single plot per rate_idx in facet_wrap
plot_snr_2 <- ggplot(data = snr, aes(x = txpower, y = snr, weight = count/sum(as.numeric(count)))) +
    geom_boxplot(aes(group=cut_width(txpower,1)), outlier.colour = "red", outlier.size=1) +
    geom_smooth(aes(colour=as.factor(txrate%%10)), stat = "smooth", method = "loess", size = 1.2) +
    scale_x_continuous(breaks = seq(min(snr$txpower), max(snr$txpower), by = txpowerscale)) +
    scale_y_continuous(breaks = seq(min(snr$snr), max(snr$snr), by = snrscale)) +
    labs(x = "Adjusted TX-Power at Transmitter [dBm]", y = "Measured SNR at Receiver [dB]") +
    theme_bw() +
    labs(title = "Validation of Transmit Power Control Using ath9k on Atheros AR9344",
         subtitle=sprintf("Boxplot of Measured SNR as Function of TX-Rate and TX-Power, Channel %s %s and Distance %s",
                          channel, htmode, distance)) +
    theme(strip.text = element_text(size=textsize),
          strip.text.x = element_text(size=textsize),
          strip.text.y = element_text(size=textsize),
          axis.text.x = element_text(angle = 0, size = textsize, colour = "black"),
          axis.text.y = element_text(size = textsize, colour = "black"),
          plot.title=element_text(color="black", face="plain", size=titlesize, margin = margin(10, 0, 10, 0)),
#          plot.subtitle=element_text(color="black", face="plain", size=textsize, margin = margin(10, 0, 10, 0)),
          strip.background = element_rect(colour='grey30', fill='grey80'),
          legend.title=element_text(colour="black", size=legendtitlesize, margin = margin(l = legendmargin), face="plain"),
          legend.text=element_text(colour="black", size=legendtextsize, face="plain"),
          legend.background = element_rect(),
          legend.position = "bottom",
          axis.title.y = element_text(angle = 90, size = axistitlesize, colour = "black", face="plain", margin = margin(r = axismarginH)),
          axis.title.x = element_text(angle = 0, size = axistitlesize, colour = "black", face="plain", margin = margin(t = 15))
    ) +
    scale_colour_brewer(name = "MCS % 8") +
    facet_wrap(~ txrate, ncol = 8, labeller = as_labeller(rate_idx))

#save plot
ggsave(plot_snr_2, file="snr_per_rate-power_v2.png", width=11, height=8, dpi=600)

#3D Scatter Plot

#~/.Rprofile:
#Sys.setenv("plotly_username"="USERNAME")
#Sys.setenv("plotly_api_key"="API_KEY")
home = Sys.getenv("HOME")
profile = paste ( home, "/.Rprofile", sep="")
source (profile)

# figure labels
f <- list(
    family = "Courier New, monospace",
    size = 17,
    color = "#7f7f7f ")
x_axis <- list(
    title = "TX-Power",
    titlefont = f,
    dtick = 2,
    showgrid='True',
    zeroline='True',
    showline='True',
    mirror='ticks',
    gridcolor='#bdbdbd',
    gridwidth=2,
    zerolinecolor='#969696',
    zerolinewidth=4,
    linecolor='#636363',
    ticksuffix='dBm',
    linewidth=6
)
y_axis <- list(
    title = "TX-Rate Index",
    titlefont = f,
    side = "top",
    showgrid='True',
    zeroline='True',
    showline='True',
    mirror='ticks',
    gridcolor='#bdbdbd',
    gridwidth=2,
    zerolinecolor='#969696',
    zerolinewidth=4,
    linecolor='#636363',
    linewidth=6
)
z_axis <- list(
    title = "SNR   ",
    titlefont = f,
    showgrid='True',
    zeroline='True',
    showline='True',
    mirror='ticks',
    gridcolor='#bdbdbd',
    gridwidth=2,
    zerolinecolor='#969696',
    zerolinewidth=4,
    linecolor='#636363',
    linewidth=6,
    ticksuffix='dB'
)

snr_3d <- plot_ly(mean_snr,
        x = ~txpower,
        y = ~txrate,
        z = ~weighted_snr,
        type = "scatter3d",
        mode = "markers",
        color = ~ weighted_snr, colors=c("green","red"),
        hoverinfo = 'text',
        text = ~paste('TX-Rate Index: ', txrate,
                      '<br>TX-Power:', txpower, ' dBm',
                      '<br>SNR:', txpower, ' dB'),
        marker = list( size = 4, opacity = 0.8,
                       colorbar = list (thickness = 10,
                                        title = 'SNR [dB]'))
        ) %>%
    layout(title = 'Validation of Transmit Power Control Using ath9k on Atheros AR9344 
                    <br> Measured Mean-SNR as Function of TX-Rate and TX-Power',
           titlefont = list(size = 18),
           scene = list(xaxis = x_axis,
                        yaxis = y_axis,
                        zaxis = z_axis,
                        aspectratio = list(x=2,y=3,z=1)
    )
) 

#plot 3d snr
plotly_IMAGE(snr_3d, format = "png", out_file = "mean_snr_3d.png")


#if (!require("webshot")) install.packages("webshot")
## RSelenium
#tmpFile <- tempfile(fileext = ".png")
#export(plot_ly(mean_snr,
#               x = ~txpower,
#               y = ~txrate,
#               z = ~weighted_snr,
#               type = "scatter3d",
#               mode = "markers",
#               color = ~ weighted_snr, colors=c("green","red"),
#               hoverinfo = 'text',
#               text = ~paste('TX-Rate Index: ', txrate,
#                             '<br>TX-Power:', txpower, ' dBm',
#                             '<br>SNR:', txpower, ' dB'),
#               marker = list( size = 3 , opacity = 0.8,
#                              colorbar = list (thickness = 10,
#                                               title = 'SNR [dB]'))
#) %>%
#    layout(title = 'Validation of Transmit Power Control Using ath9k on Atheros AR9344 
#                    <br> Measured Mean-SNR as Function of TX-Rate and TX-Power',
#           titlefont = list(size = 18),
#           scene = list(xaxis = x_axis,
#                        yaxis = y_axis,
#                        zaxis = z_axis,
#                        aspectratio = list(x=2,y=3,z=1)
#           )
#    ) , file = tmpFile, selenium = RSelenium::rsDriver)
#browseURL(tmpFile)
    


