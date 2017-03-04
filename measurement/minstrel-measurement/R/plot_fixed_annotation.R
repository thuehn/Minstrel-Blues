library(rgl)

rates <- scan('rates.txt') # x
rates <- c(rates)

powers <- scan('powers.txt') # y
powers <- c(powers)

max <- scan('snrs-max.txt')
max <- matrix(max, ncol=3, byrow=TRUE)

min <- scan('snrs-min.txt')
min <- matrix(min, ncol=3, byrow=TRUE)

#avg <- scan('snrs-avg.txt')
#avg <- matrix(avg, ncol=3, byrow=TRUE)

persp3d (rates,powers,min,col="firebrick")
persp3d (rates,powers,max,col="skyblue")
rgl.snapshot("plot.png")
