library(rgl)
library(plot3D)

rates <- scan('rates.txt') # x
rates <- c(rates)

powers <- scan('powers.txt') # y
powers <- c(powers)

max <- scan('snrs-max.txt')
max <- matrix(max, ncol=length(rates), byrow=TRUE)

min <- scan('snrs-min.txt')
min <- matrix(min, ncol=length(rates), byrow=TRUE)

avg <- scan('snrs-avg.txt')
avg <- matrix(avg, ncol=length(rates), byrow=TRUE)

#persp3d (rates,powers,avg,col="firebrick")
persp3d ( x=powers,y=rates,z=max,col="skyblue")
persp3d ( x=powers, y=rates, z=avg, col="skyblue", plot = FALSE)
Vx <- avg[-1, ] - avg[-length(avg), ]

#image3D (x = rates, y = powers, z = -255, colvar = NULL,
#         col = "blue", facets = TRUE)
#image3D (x = rates, y = powers, z = -255, colvar = NULL,
#         col = "blue", facets = TRUE, plot = FALSE)

contour3D(x = rates, y = powers, z = -255+0.01, colvar = avg*-1, add = TRUE,
          col = "black", plot = TRUE)

#persp3D (z = min, zlim = c(-60, 200), phi = 20,
#         colkey = list(length = 0.2, width = 0.4, shift = 0.15,
#                        cex.axis = 0.8, cex.clab = 0.85), lighting = TRUE, lphi = 90,
#         clab = c("","height","m"), bty = "f", plot = FALSE)
# create gradient in x-direction
#Vx <- avg[-1, ] - avg[-nrow(avg), ]

# add as image with own color key, at bottom
#image3D (z = -60, colvar = Vx/10, add = TRUE,
#         colkey = list(length = 0.2, width = 0.4, shift = -0.15,
#                       cex.axis = 0.8, cex.clab = 0.85),
#         clab = c("","gradient","m/m"), plot = FALSE)

# add contour
#contour3D(z = -60+0.01, colvar = Vx/10, add = TRUE,
#          col = "black", plot = TRUE)


rgl.snapshot("fixed-SNR.png")
