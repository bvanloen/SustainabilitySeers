library(purrr)
load("~/SustainabilitySeers/data_download_code/data/ensembleParameters.Rdata")
source("~/SustainabilitySeers/Data_Download_Functions/GEFS_download.R")

# Load covariate data ----
source("~/SustainabilitySeers/data_download_code/01_datatargetdownload.R") # NEE
source("~/SustainabilitySeers/data_download_code/01A_NOAA_datadownload.R") # weather

#function for the forecasts.
nee_forecast <- function(ensemble) {
  params <- ensemble$params
  #grab met
  met <- ensemble$met
  temp <- met$pred_daily[which(met$variable == "air_temperature")]
  precip <- met$pred_daily[which(met$variable == "precipitation_flux")]
  humid <- met$pred_daily[which(met$variable == "relative_humidity")]
  Pres <- met$pred_daily[which(met$variable == "air_pressure")]
  LW <- met$pred_daily[which(met$variable == "surface_downwelling_shortwave_flux_in_air")]
  SW <- met$pred_daily[which(met$variable == "surface_downwelling_longwave_flux_in_air")]
  #forecast
  x_ic <- ensemble$x_ic
  mu <- rep(NA, length(temp))
  mu[1] <- x_ic
  for (t in 2:length(temp)) {
    new_nee <- mu[t-1]  + 
      params["betaX"]*mu[t-1] + 
      params["betaIntercept"] + 
      params["betaTemp"]*temp[t] + 
      params["betaPrecip"]*precip[t] + 
      params["betahumid"]*humid[t] +
      params["betaSWFlux"]*SW[t] +
      params["betaPress"]*Pres[t] +
      params["betaLWFlux"]*LW[t]
    mu[t] <- rnorm(1, new_nee, 1/sqrt(params["tau_add"]))
  }
  mu
}
#we can also setup ensemble sizes and sample from the parameter spaces.
ens <- 1000
#grab met data.
#accessing GEFS.
time_points <- seq(as.Date("2024-01-01"), as.Date("2024-01-31"), "1 day")
met_variables <- c("precipitation_flux", 
                   "air_temperature",
                   "air_pressure",
                   "relative_humidity", 
                   "surface_downwelling_shortwave_flux_in_air",
                   "surface_downwelling_longwave_flux_in_air")

site_ensemble <- vector("list", length(params))
#loop over sites
for (i in seq_along(params)) {
  #prep GEFs met.
  met <- list()
  print(paste0("Downloading GEFS weather forecasts from ", 
               time_points[1], " to ", 
               time_points[length(time_points)], 
               " for ", params[[i]]$site_id))
  #download GEFs
  pb <- utils::txtProgressBar(min = 0, max = length(time_points), style = 3)
  for (j in seq_along(time_points)) {
    met[[j]] <- GEFS_download(date = time_points[j], site_name = params[[i]]$site_id, variables = met_variables, is.daily = T)
    utils::setTxtProgressBar(pb, j)
  }
  met <- do.call(rbind, met)
  #write parameters into ensembles
  ENS <- vector("list", ens)
  for (j in seq_along(ENS)) {
    #sample met data
    ens.met <- met[which(met$parameter == sample(1:31, 1)),]
    ENS[[j]] <- list(params = params[[i]]$params[j,],
                     met = ens.met,
                     x_ic = params[[i]]$predict[j])
  }
  #forecast
  mu <- ENS %>% purrr::map(nee_forecast) %>% dplyr::bind_cols() %>% as.data.frame() %>% `colnames<-`(time_points)
  #store outputs
  site_ensemble[[i]] <- list(data = ENS, forecast = mu)
}

#time series plot.
#take BART for example
mu <- site_ensemble[[1]]$forecast
ci <- apply(mu,1,quantile,c(0.025,0.5,0.975)) ## model was fit on log scale
plot(time_points, ci[3,], type="l", ylim=c(min(ci), max(ci)), xlab = "Date", ylab="NEE", main="NEE Forecasts")
ecoforecastR::ciEnvelope(time_points,ci[1,],ci[3,],col=ecoforecastR::col.alpha("lightBlue",0.75))
lines(time_points, ci[1,])
lines(time_points, ci[2,], col=2)

# Plot OSBS
mu2 <- site_ensemble[[2]]$forecast
ci2 <- apply(mu2,1,quantile,c(0.025,0.5,0.975)) ## model was fit on log scale
plot(time_points, ci2[3,], type="l", ylim=c(min(ci2), max(ci2)), xlab = "Date", ylab="NEE", main="NEE Forecasts")
ecoforecastR::ciEnvelope(time_points,ci2[1,],ci2[3,],col=ecoforecastR::col.alpha("lightBlue",0.75))
lines(time_points, ci2[1,])
lines(time_points, ci2[2,], col=2)

# Plot KONZ
mu3 <- site_ensemble[[3]]$forecast
ci3 <- apply(mu3,1,quantile,c(0.025,0.5,0.975)) ## model was fit on log scale
plot(time_points, ci3[3,], type="l", ylim=c(min(ci3), max(ci3)), xlab = "Date", ylab="NEE", main="NEE Forecasts")
ecoforecastR::ciEnvelope(time_points,ci3[1,],ci3[3,],col=ecoforecastR::col.alpha("lightBlue",0.75))
lines(time_points, ci3[1,])
lines(time_points, ci3[2,], col=2)

# Plot SRER
mu4 <- site_ensemble[[4]]$forecast
ci4 <- apply(mu4,1,quantile,c(0.025,0.5,0.975)) ## model was fit on log scale
plot(time_points, ci4[3,], type="l", ylim=c(min(ci4), max(ci4)), xlab = "Date", ylab="NEE", main="NEE Forecasts")
ecoforecastR::ciEnvelope(time_points,ci4[1,],ci4[3,],col=ecoforecastR::col.alpha("lightBlue",0.75))
lines(time_points, ci4[1,])
lines(time_points, ci4[2,], col=2)

