


## ----readData, results='hold', purl=TRUE, cache=FALSE--------------------

library(data.table, warn.conflicts = FALSE, quietly = TRUE, verbose = FALSE)
library(ggplot2, warn.conflicts = FALSE, quietly = TRUE, verbose = FALSE)
library(gridExtra, warn.conflicts = FALSE, quietly = TRUE, verbose = FALSE)

NEI <- as.data.table(readRDS("../data/summarySCC_PM25.rds"))
SCC <- as.data.table(readRDS("../data/Source_Classification_Code.rds"))

# function to determine whether tendency increasing or decreasing
getTrend <- function(years, emiss, eps=0.005) {
    linreg <- lsfit(1:length(years)-1, emiss)
    ang <- linreg$coefficients[2]/(max(emiss)-min(emiss))
    return(ifelse(ang < -1*eps, "decreasing", ifelse(ang > eps, "increasing", "stable")))
}
# table of tendencies for each facet
TrendTable <- function(dt, byCol, margin=FALSE, eps=0.005) {
    evalX <- function(txt) {eval(parse(text=txt))}
    st <- evalX(paste0("dt[ ,sum(Emissions), by=list(year,",byCol,")]"))
    tt <- evalX(paste0("data.table(grp=levels(as.factor(st$",byCol,")))"))
    tt <- evalX(paste0("tt[,trend:=sapply(grp,function(x){t<-st[",
                       byCol,"==x];getTrend(t$year, t$V1, eps=eps)})]"))
    if (margin) {
        rbind(tt, list("(all)",getTrend(st$year, st$V1, eps=eps)))
    }
    return(tt)
}


## ----plot1, results='hide', purl=TRUE, fig.width=6, fig.height=4---------
# Have total emissions from PM2.5 decreased in the United States from 1999 to 2008?

# total emissions for all USA by year
SUM <- NEI[ ,sum(Emissions), by=year][ ,`:=`(totEm=V1,V1=NULL)]
trend <- getTrend(SUM$year, SUM$totEm)

par(bg = "white", mar = c(5,5,5,2), oma = c(0,0,0,1))
barplot(SUM$totEm, col = "red", names.arg = SUM$year,
     main = "Trend of Total PM2.5 Emissions\nUSA, 1999 to 2008",
     xlab = "Year", ylab = "Total PM2.5 in tons")
abline(lsfit(1:length(SUM$year)-1, SUM$totEm), lwd = 2, col = "blue")
legend("topright",paste("tendency:", trend), 
       lty = "solid", lwd = 2, col = "blue", bty = "n", inset = c(0.01, -0.05))

# copy the screen plot to png file
noprint <- dev.copy(png, file = "../plot1.png",
                         width = 720, height = 480, units = "px")
noprint <- dev.off() ## Don't forget to close the PNG device!



## ----plot2, results='hide', purl=TRUE, fig.width=6, fig.height=4---------
# Have total emissions from PM2.5 decreased in the **Baltimore City, Maryland** 
# (`fips == "24510"`) from 1999 to 2008?

# total emissions for Baltimore by year
SUM <- NEI[fips == "24510", ][, sum(Emissions), by=year][ ,`:=`(totEm=V1,V1=NULL)]
trend <- getTrend(SUM$year, SUM$totEm)

par(bg = "white", mar = c(5,5,5,2), oma = c(0,0,0,1))
barplot(SUM$totEm, col = "red", names.arg = SUM$year, ylim = c(0, 4000),
     main = "Trend of Total PM2.5 Emissions\nBaltimore City / MD, 1999 to 2008",
     xlab = "Year", ylab = "Total PM2.5 in tons")
abline(lsfit(1:length(SUM$year)-1, SUM$totEm), lwd = 2, col = "blue")
legend("topright",paste("tendency:", trend), 
       lty = "solid", lwd = 2, col = "blue", bty = "n", inset = c(0.01, -0.05), cex = 1.0)

# copy the screen plot to png file
noprint <- dev.copy(png, file = "../plot2.png",
                         width = 720, height = 480, units = "px")
noprint <- dev.off() ## Don't forget to close the PNG device!



## ----plot3, results='hide', purl=TRUE, fig.width=6, fig.height=4---------
# Of the 4 **type** of sources which increase/decrease
# for **Baltimore City, Maryland** (`fips == "24510"`) from 1999 to 2008?

# Emissions Baltimore by year and type
# set type as factor in desired order (default is alphabetical)
BALT <- NEI[fips == "24510", ][ ,sum(Emissions), by=list(year,type)
          ][ ,`:=`(type=factor(type, levels=c("POINT","NONPOINT","ON-ROAD","NON-ROAD"))
                   ,Emissions=V1,V1=NULL)]

# get tendency for each type
tt <- TrendTable(BALT,"type")
setkey(BALT,type); setkey(tt,grp)
BALT <- BALT[tt][, `:=`(x=2003.4, y=2200)]

BALT

gp3 <- ggplot(BALT, aes(year,Emissions)) +
       facet_grid(. ~ type) +
       geom_bar(stat="identity", fill="red") +
       scale_x_continuous(breaks=BALT$year, labels=BALT$year) +
       geom_smooth(method = "lm", se=FALSE, size=2, colour="navy") +
       geom_text(aes(x, y, label=trend), data=BALT, colour="navy") +
       ggtitle("Trends of PM2.5 Emissions per Type\nBaltimore City / MD, 1999 to 2008") +
       theme(strip.text.x = element_text(size=14, face="bold", colour="#5050AA"),
             plot.title = element_text(lineheight=.9, face="bold", size=16))
print(gp3)

# copy the screen plot to png file
noprint <- dev.copy(png, file = "../plot3.png",
                         width = 720, height = 480, units = "px")
noprint <- dev.off() ## Don't forget to close the PNG device!



## ----plot4, results='hide', purl=TRUE, fig.width=6, fig.height=8---------
# How have emissions from coal combustion-related sources changed 
# in the USA from 1999 to 2008?

# COAL COMBUSTION-RELATED SOURCES:
# ==> from SCC select sources with "Short.Name" containing "comb" and ("coal" or "lignite")
#     (ignoring lower-/uppercase) (some "lignite" short names do not contain "coal")

SCCsel <- SCC[grep("comb.+(coal|lignite)", Short.Name, ignore.case=TRUE, value=FALSE), 
                list(SCC,SCC.Level.Two)]
# resume SCC.Level.Two to "Electric Generation" and "Others"
SCCsel <- SCCsel[, `:=`(L2res=ifelse(SCC.Level.Two=="Electric Generation",
                                     "Electric Generation", "Others"))]

# ==> select these SCCs from NEI, merging in columns SCC.Level.Two, L2res (for grouping)
#     (in SQL terms: INNER JOIN)

setkey(NEI,SCC); setkey(SCCsel,SCC)
COAL <- NEI[, list(SCC,year,Emissions)][SCCsel, nomatch=0]

# PLOT a): facetting by resumed level L2res
#          - can't use margins=TRUE on facet_grid; trend labels get confused,
#            so add the total per year
COALa <- COAL[ ,sum(Emissions), by=list(year,L2res)
           ][ ,`:=`(Emissions=V1/1000,V1=NULL)]     # kilo-tons
COALa <- rbind(COALa, COALa[ ,sum(Emissions), by=year,
           ][ ,`:=`(Emissions=V1,V1=NULL,L2res="TOTAL")])     # already kilo-tons

# get tendency for each L2res and (all)
tt <- TrendTable(COALa,"L2res", margin=FALSE, eps=0.1)
maxEm <- COALa[,ceiling(max(Emissions))]
setkey(COALa,L2res); setkey(tt,grp)                 # "ON" clause for join
COALa <- COALa[tt][, `:=`(x=2003.5, y=maxEm+20)]    # join trends, coords for labels

gp4a <- ggplot(COALa, aes(year,Emissions)) +
        facet_grid(. ~ L2res, margins=FALSE) +
        geom_bar(stat="identity", fill="red") +
        scale_x_continuous(breaks=COALa$year, labels=COALa$year) +
        scale_y_continuous(name="Emissions in 1000 tons") +
        geom_smooth(method = "lm", se=FALSE, size=2, colour="navy") +
        geom_text(aes(x, y, label=trend), data=COALa, colour="navy") +
        xlab("Year") +
        ggtitle(paste("Trends for PM2.5 Emissions from Coal Combustion-Related Sources",
                      "USA, 1999 to 2008",
                      sep = "\n")) +
        theme(strip.text.x = element_text(size=10, face="bold", colour="#5050AA"),
              plot.title = element_text(lineheight=.9, face="bold", size=12))

# PLOT b): facetting by SCC.Level.Two where L2res == "Others"
#          except "Space Heaters" and "Total Area...."
COALb <- COAL[L2res=="Others" & 
              !SCC.Level.Two %in% c("Space Heaters","Total Area Source Fuel Combustion",
                                    "Electric Utility"), 
            ][, sum(Emissions), by=list(year,SCC.Level.Two)
            ][ ,`:=`(Emissions=V1/1000,V1=NULL,L2=as.character(SCC.Level.Two))]     # kilo-tons

# get tendency for each SCC.Level.Two
tt <- TrendTable(COALb,"L2", margin=FALSE, eps=0.005)
maxEm <- COALb[,ceiling(max(Emissions))]
setkey(COALb,L2); setkey(tt,grp)                    # "ON" clause for join
COALb <- COALb[tt][, `:=`(x=2003.5, y=maxEm+10)]    # join trends, coords for labels

gp4b <- ggplot(COALb, aes(year,Emissions)) +
        facet_grid(. ~ SCC.Level.Two, margins=FALSE) +
        geom_bar(stat="identity", fill="red") +
        scale_x_continuous(breaks=COALb$year, labels=COALb$year) +
        scale_y_continuous(name="Emissions in 1000 tons") +
        geom_smooth(method = "lm", se=FALSE, size=2, colour="navy") +
        geom_text(aes(x, y, label=trend), data=COALb, colour="navy") +
        xlab(paste0("Year\n\n",
                    "Emissions from sources with Short.Name ",
                    "containing 'comb' and ('coal' or 'lignite')",
                    " grouped by SCC.Level.Two")) +
        ggtitle(" ... details of some of the 'Others' from above ...") +
        theme(strip.text.x = element_text(size=10, face="bold", colour="#5050AA"),
              plot.title = element_text(face="bold", size=12))

# put the two plots on one page
grid.newpage()
pushViewport(viewport(layout = grid.layout(2, 1)))
print(gp4a, vp = viewport(layout.pos.row = 1, layout.pos.col = 1))
print(gp4b, vp = viewport(layout.pos.row = 2, layout.pos.col = 1))

# copy the screen plot to png file
noprint <- dev.copy(png, file = "../plot4.png",
                         width = 720, height = 960, units = "px")
noprint <- dev.off() ## Don't forget to close the PNG device!



## ----selMotVehic, results='hide', purl=TRUE------------------------------

# A function to select SCCs for "motor vehicle emissions" used in questions 5 and 6

# MOTOR VEHICLE SOURCES:
# ==> I chose to include all Onroad Categories plus Recreational Vehicles,
#     but not airplanes, locomotives, machinery etc from  Mobile EI.Sectors
# ==> from SCC select sources with "Data.Category" equal to "Onroad"
#     and add SCCs with "recreat" in Short.Name (they all have "mobile" in EI.Sector)
# ==> make fuel groups "Diesel", "Gasoline" by grepping SCC.Level.Two

selMotorVehic <- function(SCC) {
    
  s <- SCC[Data.Category == "Onroad", ]                             # all Onroad catgories
  s <- rbind(s, SCC[grep("recreat",Short.Name,ignore.case=TRUE), ]) # add recreational vehicles
  s <- s[, list(SCC, SCC.Level.Two, Data.Category)                  # only these columns needed
       ][, fuel:=as.factor("Gasoline")                              # group "Gasoline"
       ][grep("Diesel", SCC.Level.Two), fuel:="Diesel"]             # .. or "Diesel"

}



## ----plot5, results='hide', purl=TRUE, fig.width=6, fig.height=4---------
# How have emissions from motor vehicle sources changed
# for **Baltimore City, Maryland** (`fips == "24510"`) from 1999 to 2008?

# call function to select SCCs for "motor vehicle emissions" used in questions 5 and 6
SCCsel <- selMotorVehic(SCC)

# ==> select these SCCs from NEI for Baltimore, merging in column Fuel
#     (in SQL terms: INNER JOIN)

setkey(NEI,SCC); setkey(SCCsel,SCC)                     # "ON clause" for join
BALT <- NEI[fips == "24510", list(SCC,year,Emissions)   # Baltimore City, MD
          ][SCCsel[, list(SCC, fuel)], nomatch=0        # inner join on selected SCC
          ][ ,sum(Emissions), by=list(year,fuel)        # sum per year and fuel group
          ][ ,`:=`(Emissions=V1,V1=NULL)]
# can't use margins=TRUE on facet_grid (trend labels get confused), so add the total per year
BALT <- rbind(BALT, BALT[ ,sum(Emissions), by=year,
           ][ ,`:=`(Emissions=V1,V1=NULL,fuel="TOTAL")])

# get tendency for each fuel group
setkeyv(BALT,c("year","fuel"))
tt <- TrendTable(BALT,"fuel")
maxEm <- BALT[,ceiling(max(Emissions))]
setkey(BALT,fuel); setkey(tt,grp)                # "ON" clause for join
BALT <- BALT[tt][, `:=`(x=2003.5, y=maxEm+20)]   # join trends, coords for labels

gp5 <- ggplot(BALT, aes(year,Emissions)) +
       facet_grid(. ~ fuel, margins=FALSE) +
       geom_bar(stat="identity", fill="red") +
       scale_x_continuous(breaks=BALT$year, labels=BALT$year) +
       geom_smooth(method = "lm", se=FALSE, size=2, colour="navy") +
       geom_text(aes(x, y, label=trend), colour="navy") +
       xlab(paste0("Year\n\n",
                   "Emission from sources with SCC.Level.Two containing 'vehic' ",
                   "and Data.Category == 'Onroad'")) +
       ylab("Emissions in tons") +
       ggtitle(paste("Trends for PM2.5 Emissions for Motor Vehicles",
                     "Baltimore City / MD, 1999 to 2008",
                     sep = "\n")) +
       theme(strip.text.x = element_text(size=14, face="bold", colour="#5050AA"),
             plot.title = element_text(lineheight=.9, face="bold", size=16))
print(gp5)

# copy the screen plot to png file
noprint <- dev.copy(png, file = "../plot5.png",
                         width = 720, height = 480, units = "px")
noprint <- dev.off() ## Don't forget to close the PNG device!



## ----plot6, results='hide', purl=TRUE, fig.width=9, fig.height=7---------
# Which city has seen greater changes in motor vehicle emissions from 1999 to 2008?
## **Baltimore City, Maryland** (`fips == "24510"`)
## **Los Angeles County, California** (`fips == "06037"`)

# POPULATION:
# ==> Baltimore City, MD from http://research.stlouisfed.org/fred2/series/MDBALT5POP#
#     Los Angeles County from http://research.stlouisfed.org/fred2/series/CALOSA7POP#
# ==> downloaded .xls (sic!) files; result hard coded here:

POP <- data.table(
        year = c(rep(1999,2),rep(2002,2),rep(2005,2),rep(2008,2)),
        fips = rep(c("24510", "06037"), 4),    # Baltimore City, L.A. County
        pop = c( 657441, 9437290, 642514, 9717836, 640064, 9802296, 637901, 9771522)
    )

# AREA:
# ==> Baltimore City, MD from http://en.wikipedia.org/wiki/List_of_counties_in_Maryland
#     Los Angeles County from http://en.wikipedia.org/wiki/List_of_counties_in_California
# ==> result hard coded here, area in square miles

AREA <- data.table(
        year = c(rep(1999,2),rep(2002,2),rep(2005,2),rep(2008,2)),
        fips = rep(c("24510", "06037"), 4),    # Baltimore City, L.A. County
        area = rep(c(92, 4060), 4)             # square miles Balt, L.A.
    )


# call function to select SCCs for "motor vehicle emissions" used in questions 5 and 6
SCCsel <- selMotorVehic(SCC)

# ==> select these SCCs from NEI for Baltimore and L.A., merging in column Fuel and Population
#     (in SQL terms: INNER JOIN)

setkey(NEI,SCC); setkey(SCCsel,SCC)                     # "ON clause" for join
BALA <- NEI[fips %in% c("24510","06037"),               # Baltimore City, L.A. County
                list(SCC, year, fips, Emissions)        # .. cols to keep
          ][SCCsel[, list(SCC, fuel)], nomatch=0        # inner join on selected SCC
          ][ ,sum(Emissions), by=list(year,fips,fuel)   # sum per year, county and fuel group
          ][ ,`:=`(totEm=V1,V1=NULL,                    # rename total Emissions (in tons)
                   fips=as.factor(fips))]               # fips as factor for plot
# add the total of all fuel types per year
BALA <- rbind(BALA, BALA[ ,sum(totEm), by=list(year,fips)
           ][ ,`:=`(totEm=V1,V1=NULL,fuel="ALL FUELS")])
# join in population and area per fips and year
setkeyv(BALA,c("year","fips"))                                 # "ON clause" for join
setkeyv(POP,c("year","fips")); setkeyv(AREA,c("year","fips"))
BALA <- BALA[POP]                                              # join population for each year
BALA <- BALA[AREA]                                             # join area in sq mi
# compute Emissions in pounds per capita (1 ton = 2000 lbs) and in tons per square mile
BALA <- BALA[, `:=`(popEm=2000*totEm/pop, areEm=totEm/area)]
# index the Emissions so that 1999 = 100%
B99 <- BALA[year == 1999, ][ ,list(fips, fuel, totEm, popEm, areEm)  # values for 1999
          ][ ,`:=`(tot99=totEm, pop99=popEm, are99=areEm, 
                   totEm=NULL, popEm=NULL, areEm=NULL)]
setkeyv(BALA,c("fips","fuel")); setkeyv(B99,c("fips","fuel"))  # "ON clause" for join
BALA <- BALA[B99                                               # join in Emissions of 1999
            ][,`:=`(iTotEm=round(100*totEm/tot99),             # calculate indexed by 1999 in %
                    iPopEm=round(100*popEm/pop99),
                    iAreEm=round(100*areEm/are99))]

# get tendency for each fuel group
# setkeyv(BALA,c("year","county"))
# tt <- TrendTable(BALA,"county")
# maxEm <- BALA[,ceiling(max(Emissions))]
# setkey(BALA,fuel); setkey(tt,grp)                # "ON" clause for join
# BALA <- BALA[tt][, `:=`(x=2003.5, y=maxEm+20)]   # join trends, coords for labels

facet_labelling <- function(variable, value) {
    ifelse(value=="06037","Los Angeles",
           ifelse(value=="24510","Baltimore City",
                  label_value(variable,value)))
}

# prepare plots for total Emissions, relative, by area and by population

g6a <- ggplot(BALA, aes(year,totEm)) +
       facet_grid(fips ~ fuel, margins=FALSE, labeller="facet_labelling") +
       geom_bar(stat="identity", fill="red") +
       scale_x_continuous(breaks=BALA$year, labels=BALA$year) +
       geom_smooth(method = "lm", se=FALSE, size=2, colour="navy") +
       ylab("Emissions in tons") +
       ggtitle(paste("comparing total emissions",
                     sep = "\n")) +
       theme(
             strip.text.x = element_text(size=14, face="bold", colour="#5050AA"),
             strip.text.y = element_text(size=11, face="bold", colour="Navy"),
             plot.title = element_text(lineheight=.9, face="bold", size=13))

g6b <- ggplot(BALA, aes(year,iTotEm)) +
       facet_grid(fips ~ fuel, margins=FALSE, labeller="facet_labelling") +
       geom_bar(stat="identity", fill="red") +
       scale_x_continuous(breaks=BALA$year, labels=BALA$year) +
       geom_smooth(method = "lm", se=FALSE, size=2, colour="navy") +
       ylab("indexed: 1999 = 100%") +
       ggtitle(paste("comparing total emissions in % of 1999",
                     sep = "\n")) +
       theme(
             strip.text.x = element_text(size=14, face="bold", colour="#5050AA"),
             strip.text.y = element_text(size=11, face="bold", colour="Navy"),
             plot.title = element_text(lineheight=.9, face="bold", size=13))

g6c <- ggplot(BALA, aes(year,areEm)) +
       facet_grid(fips ~ fuel, margins=FALSE, labeller="facet_labelling") +
       geom_bar(stat="identity", fill="red") +
       scale_x_continuous(breaks=BALA$year, labels=BALA$year) +
       geom_smooth(method = "lm", se=FALSE, size=2, colour="navy") +
       ylab("Emissions in tons per square mile") +
       ggtitle(paste("comparing emissions in tons per square mile of county area",
                     sep = "\n")) +
       theme(
             strip.text.x = element_text(size=14, face="bold", colour="#5050AA"),
             strip.text.y = element_text(size=11, face="bold", colour="Navy"),
             plot.title = element_text(lineheight=.9, face="bold", size=13))

g6d <- ggplot(BALA, aes(year,popEm)) +
       facet_grid(fips ~ fuel, margins=FALSE, labeller="facet_labelling") +
       geom_bar(stat="identity", fill="red") +
       scale_x_continuous(breaks=BALA$year, labels=BALA$year) +
       geom_smooth(method = "lm", se=FALSE, size=2, colour="navy") +
       ylab("Emissions in lbs per capita") +
       ggtitle(paste("comparing emissions in pounds (lbs) per capita",
                     sep = "\n")) +
       theme(
             strip.text.x = element_text(size=14, face="bold", colour="#5050AA"),
             strip.text.y = element_text(size=11, face="bold", colour="Navy"),
             plot.title = element_text(lineheight=.9, face="bold", size=13))

# put the four plots on one page using gridExtra
# http://www.r-bloggers.com/extra-extra-get-your-gridextra/

grid.arrange(g6a, g6b, g6c, g6d, ncol=2,
             main = paste("Emissions from Motor Vehicle sources",
                          "Los Angeles County vs Baltimore City",
                          sep="\n"),
             sub  = paste("Emission from sources with Data.Category == 'Onroad'",
                          "or Short.Name contains 'recreat'",
                          sep=" ")
             )

# copy the screen plot to png file
noprint <- dev.copy(png, file = "../plot6.png",
                         width = 1020, height = 720, units = "px")
noprint <- dev.off() ## Don't forget to close the PNG device!


