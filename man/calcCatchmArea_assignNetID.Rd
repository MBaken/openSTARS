% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/calc_edges.R
\name{calcCatchmArea_assignNetID}
\alias{calcCatchmArea_assignNetID}
\title{Calculate total catchment area of a stream segment and assign a network id.}
\usage{
calcCatchmArea_assignNetID(dt, id, net_ID)
}
\arguments{
\item{dt}{data.table containing the attributes of the stream segments}

\item{id}{integer; 'stream' of the stream segment}

\item{netID}{integer; network ID}
}
\value{
Total catchment area upstream of the segment
}
\description{
Recursive function to calculate the upstream area of each stream segment and
assign a unique network id. It is called by \code{\link{calc_edges}} for each
outlet and should not be called by the user.
}
\details{
calcCatchmArea_assignNetID
}
\examples{
\dontrun{
 outlets <- dt.streams[next_str == -1, stream]
 netID <- 1
 for(i in outlets){
   calcCatchmArea_assignNetID(dt.streams, id = i, netID)
   netID <- netID + 1
 }
}
}
\author{
Mira Kattwinkel, \email{mira.kattwinkel@gmx.net}
}
\keyword{internal}
