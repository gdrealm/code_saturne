!-------------------------------------------------------------------------------

!     This file is part of the Code_Saturne Kernel, element of the
!     Code_Saturne CFD tool.

!     Copyright (C) 1998-2011 EDF S.A., France

!     contact: saturne-support@edf.fr

!     The Code_Saturne Kernel is free software; you can redistribute it
!     and/or modify it under the terms of the GNU General Public License
!     as published by the Free Software Foundation; either version 2 of
!     the License, or (at your option) any later version.

!     The Code_Saturne Kernel is distributed in the hope that it will be
!     useful, but WITHOUT ANY WARRANTY; without even the implied warranty
!     of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
!     GNU General Public License for more details.

!     You should have received a copy of the GNU General Public License
!     along with the Code_Saturne Kernel; if not, write to the
!     Free Software Foundation, Inc.,
!     51 Franklin St, Fifth Floor,
!     Boston, MA  02110-1301  USA

!-------------------------------------------------------------------------------

subroutine majgeo &
!================

 ( ncel2  , ncele2 , nfac2  , nfabo2 , nsom2  ,                   &
   lndfa2 , lndfb2 , ncelb2 , ncelg2 , nfacg2 , nfbrg2 , nsomg2 , &
   nthdi2 , nthdb2 , ngrpi2 , ngrpb2 , idxfi  , idxfb  ,          &
   iface2 , ifabo2 , ifmfb2 , ifmce2 , iprfm2 ,                   &
   ipnfa2 , nodfa2 , ipnfb2 , nodfb2 , icelb2 ,                   &
   volmn2 , volmx2 , voltt2 ,                                     &
   xyzce2 , surfa2 , surfb2 , cdgfa2 , cdgfb2 , xyzno2 ,          &
   volum2 , srfan2 , srfbn2 , dist2  , distb2 , pond2  ,          &
   dijpf2 , diipb2 , dofij2 )

!===============================================================================
! Purpose:
! -------

! Pass mesh information from C to Fortran and compute additional Fortran arrays

!-------------------------------------------------------------------------------
! Arguments
!__________________.____._____.________________________________________________.
! name             !type!mode ! role                                           !
!__________________!____!_____!________________________________________________!
! ncel2            ! i  ! <-- ! nombre de cellules                             !
! ncele2           ! i  ! <-- ! nombre d'elements halo compris                 !
! nfac2            ! i  ! <-- ! nombre de faces internes                       !
! nfabo2           ! i  ! <-- ! nombre de faces de bord                        !
! nsom2            ! i  ! <-- ! nombre de sommets                              !
! lndfa2           ! i  ! <-- ! taille de lndfac                               !
! lndfb2           ! i  ! <-- ! taille de lndfbr                               !
! ncelb2           ! i  ! <-- ! number of boundary cells
! ncelg2           ! i  ! <-- ! nombre global de cellules                      !
! nfacg2           ! i  ! <-- ! nombre global de faces internes                !
! nfbrg2           ! i  ! <-- ! nombre global de faces de bord                 !
! nsomg2           ! i  ! <-- ! nombre global de sommets                       !
! nthdi2           ! i  ! <-- ! nb. max de threads par groupe de faces inter   !
! nthdb2           ! i  ! <-- ! nb. max de threads par groupe de faces de bord !
! ngrpi2           ! i  ! <-- ! nb. groupes de faces interieures               !
! ngrpb2           ! i  ! <-- ! nb. groupes de faces de bord                   !
! idxfi            ! i  ! <-- ! index pour faces internes                      !
! idxfb            ! ia ! <-- ! index pour faces de bord                       !
! iface2           ! ia ! <-- ! interior face->cells connectivity              !
! ifabo2           ! ia ! <-- ! boundary face->cells connectivity              !
! icelb2           ! ia ! <-- ! boundary cell list                             !
! volmn2           ! r  ! <-- ! Minimum control volume                         !
! volmx2           ! r  ! <-- ! Maximum control volume                         !
! voltt2           ! r  ! <-- ! Total   control volume                         !
! xyzce2           ! ra ! <-- ! cell centers                                   !
! surfa2           ! ra ! <-- ! interior face normals                          !
! surfb2           ! ra ! <-- ! boundary face normals                          !
! cdgfa2           ! ra ! <-- ! interior face centers                          !
! cdgfb2           ! ra ! <-- ! boundary face centers                          !
! xyzno2           ! ra ! <-- ! vertex coordinates                             !
! volum2           ! ra ! <-- ! cell volumes                                   !
! srfan2           ! ra ! <-- ! interior face surfaces                         !
! srfbn2           ! ra ! <-- ! boundary face surfaces                         !
! dist2            ! ra ! <-- ! distance IJ.Nij                                !
! distb2           ! ra ! <-- ! likewise for border faces                      !
! pond2            ! ra ! <-- ! weighting (Aij=pond Ai+(1-pond)Aj)             !
! dijpf2           ! ra ! <-- ! vector I'J'                                    !
! diipb2           ! ra ! <-- ! likewise for border faces                      !
! dofij2           ! ra ! <-- ! vector OF at interior faces                    !
!__________________!____!_____!________________________________________________!

!     Type: i (integer), r (real), s (string), a (array), l (logical),
!           and composite types (ex: ra real array)
!     mode: <-- input, --> output, <-> modifies data, --- work array
!===============================================================================

!===============================================================================
! Module files
!===============================================================================

use dimens
use paramx
use entsor
use parall
use cstphy
use mesh

!===============================================================================

implicit none

! Arguments

integer, intent(in) :: ncel2, ncele2, nfac2, nfabo2, nsom2
integer, intent(in) :: lndfa2, lndfb2
integer, intent(in) :: ncelb2
integer, intent(in) :: ncelg2, nfacg2 , nfbrg2, nsomg2
integer, intent(in) :: nthdi2, nthdb2
integer, intent(in) :: ngrpi2, ngrpb2

integer, dimension(*), intent(in) :: idxfi, idxfb

integer, dimension(2,nfac2), target :: iface2
integer, dimension(ncele2), target :: ifmce2
integer, dimension(nfabo2), target :: ifabo2, ifmfb2
integer, dimension(nfml,nprfml), target :: iprfm2
integer, dimension(nfac2+1), target :: ipnfa2
integer, dimension(lndfa2), target :: nodfa2
integer, dimension(nfabo2+1), target :: ipnfb2
integer, dimension(lndfb2), target :: nodfb2
integer, dimension(ncelb2), target :: icelb2

double precision :: volmn2, volmx2, voltt2

double precision, dimension(3,ncele2), target :: xyzce2
double precision, dimension(3,nfac2), target :: surfa2, cdgfa2, dijpf2, dofij2
double precision, dimension(3,nfabo2), target :: surfb2, cdgfb2, diipb2
double precision, dimension(3,nsom2), target :: xyzno2
double precision, dimension(ncele2), target :: volum2
double precision, dimension(nfac2), target :: srfan2, dist2, pond2
double precision, dimension(nfabo2), target :: srfbn2, distb2

! Local variables

!===============================================================================

!===============================================================================
! 1. Update number of cells, faces, and vertices
!===============================================================================

ncel = ncel2
ncelet = ncele2

nfac = nfac2
nfabor = nfabo2

lndfac = lndfa2
lndfbr = lndfb2

! Now update ndimfb
if (nfabor.eq.0) then
  ndimfb = 1
else
  ndimfb = nfabor
endif

nnod = nsom2

ncelbr = ncelb2

!===============================================================================
! 2. Global sizes
!===============================================================================

ncelgb = ncelg2
nfacgb = nfacg2
nfbrgb = nfbrg2
nsomgb = nsomg2

!===============================================================================
! 3. Initialization of thread information
!===============================================================================

call init_fortran_omp(nfac, nfabor, &
                      nthdi2, nthdb2, ngrpi2, ngrpb2, idxfi, idxfb)

!===============================================================================
! 4. Define pointers on mesh structure
!===============================================================================

ifacel => iface2(1:2,1:nfac)
ifabor => ifabo2(1:nfabor)

ifmfbr => ifmfb2(1:nfabor)
ifmcel => ifmce2(1:ncelet)
iprfml => iprfm2(1:nfml,1:nprfml)

ipnfac => ipnfa2(1:nfac+1)
nodfac => nodfa2(1:lndfac)
ipnfbr => ipnfb2(1:nfabor+1)
nodfbr => nodfb2(1:lndfbr)

icelbr => icelb2(1:ncelbr)

xyzcen => xyzce2(1:3,1:ncelet)

!===============================================================================
! 5. Define pointers on mesh quantities
!===============================================================================

surfac => surfa2(1:3,1:nfac)
surfbo => surfb2(1:3,1:nfabor)
cdgfac => cdgfa2(1:3,1:nfac)
cdgfbo => cdgfb2(1:3,1:nfabor)

xyznod => xyzno2(1:3,1:nnod)

volume => volum2(1:ncelet)

surfan => srfan2(1:nfac)
surfbn => srfbn2(1:nfabor)

dist => dist2(1:nfac)
distb => distb2(1:nfabor)

pond => pond2(1:nfac)

dijpf => dijpf2(1:3,1:nfac)
diipb => diipb2(1:3,1:nfabor)
dofij => dofij2(1:3,1:nfac)

!===============================================================================
! 6. Define cstphy variables
!===============================================================================

volmin = volmn2
volmax = volmx2
voltot = voltt2

!===============================================================================

return
end subroutine
