!-------------------------------------------------------------------------------

! This file is part of Code_Saturne, a general-purpose CFD tool.
!
! Copyright (C) 1998-2013 EDF S.A.
!
! This program is free software; you can redistribute it and/or modify it under
! the terms of the GNU General Public License as published by the Free Software
! Foundation; either version 2 of the License, or (at your option) any later
! version.
!
! This program is distributed in the hope that it will be useful, but WITHOUT
! ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
! FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
! details.
!
! You should have received a copy of the GNU General Public License along with
! this program; if not, write to the Free Software Foundation, Inc., 51 Franklin
! Street, Fifth Floor, Boston, MA 02110-1301, USA.

!-------------------------------------------------------------------------------

subroutine matrdt &
!================

 ( iconvp , idiffp , isym   ,                                     &
   coefbp , cofbfp , flumas , flumab , viscf  , viscb  ,          &
   da     )

!===============================================================================
! FONCTION :
! ----------

! CONSTRUCTION DE LA DIAGONALE DE LA
!   MATRICE DE CONVECTION UPWIND/DIFFUSION/TS
!   POUR DETERMINATION DU PAS DE TEMPS VARIABLE, COURANT, FOURIER


!-------------------------------------------------------------------------------
!ARGU                             ARGUMENTS
!__________________.____._____.________________________________________________.
! name             !type!mode ! role                                           !
!__________________!____!_____!________________________________________________!
! iconvp           ! e  ! <-- ! indicateur = 1 convection, 0 sinon             !
! idiffp           ! e  ! <-- ! indicateur = 1 diffusion , 0 sinon             !
! isym             ! e  ! <-- ! indicateur = 1 matrice symetrique              !
!                  !    !     !              2 matrice non symetrique          !
! coefbp(nfabor    ! tr ! <-- ! tab b des cl pour le pdt considere             !
! cofbfp(nfabor    ! tr ! <-- ! tab b des cl pour le pdt considere             !
! flumas(nfac)     ! tr ! <-- ! flux de masse aux faces internes               !
! flumab(nfabor    ! tr ! <-- ! flux de masse aux faces de bord                !
! viscf(nfac)      ! tr ! <-- ! visc*surface/dist aux faces internes           !
! viscb(nfabor     ! tr ! <-- ! visc*surface/dist aux faces de bord            !
! da (ncelet       ! tr ! --> ! partie diagonale de la matrice                 !
!__________________!____!_____!________________________________________________!

!     TYPE : E (ENTIER), R (REEL), A (ALPHANUMERIQUE), T (TABLEAU)
!            L (LOGIQUE)   .. ET TYPES COMPOSES (EX : TR TABLEAU REEL)
!     MODE : <-- donnee, --> resultat, <-> Donnee modifiee
!            --- tableau de travail
!===============================================================================

!===============================================================================
! Module files
!===============================================================================

use paramx
use entsor
use parall
use mesh

!===============================================================================

implicit none

! Arguments

integer          iconvp , idiffp , isym


double precision coefbp(nfabor)
double precision cofbfp(nfabor)
double precision flumas(nfac), flumab(nfabor)
double precision viscf(nfac), viscb(nfabor)
double precision da(ncelet )

! Local variables

integer          ifac, ii, jj, iel, ig, it
double precision flui, fluj, xaifa1, xaifa2

!===============================================================================

!===============================================================================
! 1. INITIALISATION
!===============================================================================

if (isym.ne.1.and.isym.ne.2) then
  write(nfecra,1000) isym
  call csexit (1)
endif

!$omp parallel do
do iel = 1, ncel
  da(iel) = 0.d0
enddo
if (ncelet.gt.ncel) then
  !$omp parallel do if(ncelet - ncel > thr_n_min)
  do iel = ncel+1, ncelet
    da(iel) = 0.d0
  enddo
endif

!===============================================================================
! 2.    CALCUL DES TERMES EXTRADIAGONAUX INUTILE
!===============================================================================

!===============================================================================
! 3.     CONTRIBUTION DES TERMES X-TRADIAGONAUX A LA DIAGONALE
!===============================================================================

if (isym.eq.2) then

  do ig = 1, ngrpi
    !$omp parallel do private(ifac, ii, jj, fluj, flui, xaifa2, xaifa1)
    do it = 1, nthrdi
      do ifac = iompli(1,ig,it), iompli(2,ig,it)
        ii = ifacel(1,ifac)
        jj = ifacel(2,ifac)
        fluj =-0.5d0*(flumas(ifac) + abs(flumas(ifac)))
        flui = 0.5d0*(flumas(ifac) - abs(flumas(ifac)))
        xaifa2 = iconvp*fluj -idiffp*viscf(ifac)
        xaifa1 = iconvp*flui -idiffp*viscf(ifac)
        da(ii) = da(ii) -xaifa2
        da(jj) = da(jj) -xaifa1
      enddo
    enddo
  enddo

else

  do ig = 1, ngrpi
    !$omp parallel do private(ifac, ii, jj, flui, xaifa1)
    do it = 1, nthrdi
      do ifac = iompli(1,ig,it), iompli(2,ig,it)
        ii = ifacel(1,ifac)
        jj = ifacel(2,ifac)
        flui = 0.5d0*(flumas(ifac) - abs(flumas(ifac)))
        xaifa1 = iconvp*flui -idiffp*viscf(ifac)
        da(ii) = da(ii) -xaifa1
        da(jj) = da(jj) -xaifa1
      enddo
    enddo
  enddo

endif

!===============================================================================
! 4.     CONTRIBUTION DES FACETTES DE BORDS A LA DIAGONALE
!===============================================================================

do ig = 1, ngrpb
  !$omp parallel do private(ifac, ii, flui, fluj) if(nfabor > thr_n_min)
  do it = 1, nthrdb
    do ifac = iomplb(1,ig,it), iomplb(2,ig,it)
      ii = ifabor(ifac)
      flui = 0.5d0*(flumab(ifac) - abs(flumab(ifac)))
      fluj =-0.5d0*(flumab(ifac) + abs(flumab(ifac)))
      da(ii) = da(ii) +iconvp*(-fluj + flui*coefbp(ifac))       &
                      +idiffp*viscb(ifac)*cofbfp(ifac)
    enddo
  enddo
enddo

!--------
! Formats
!--------

#if defined(_CS_LANG_FR)

 1000 format(                                                     &
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/,&
'@ @@ ATTENTION : ARRET DANS matrdt                           ',/,&
'@    =========                                               ',/,&
'@     APPEL DE matrdt              AVEC ISYM   = ',I10        ,/,&
'@                                                            ',/,&
'@  Le calcul ne peut pas etre execute.                       ',/,&
'@                                                            ',/,&
'@  Contacter l''assistance.                                  ',/,&
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/)

#else

 1000 format(                                                     &
'@'                                                            ,/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@'                                                            ,/,&
'@ @@ WARNING: ABORT IN matrdt'                                ,/,&
'@    ========'                                                ,/,&
'@     matrdt CALLED                WITH ISYM   = ',I10        ,/,&
'@'                                                            ,/,&
'@  The calculation will not be run.'                          ,/,&
'@'                                                            ,/,&
'@  Contact support.'                                          ,/,&
'@'                                                            ,/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@'                                                            ,/)

#endif

!----
! End
!----

return

end subroutine