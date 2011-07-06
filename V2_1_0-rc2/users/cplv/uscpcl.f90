!-------------------------------------------------------------------------------

!VERS


!     This file is part of the Code_Saturne Kernel, element of the
!     Code_Saturne CFD tool.

!     Copyright (C) 1998-2009 EDF S.A., France

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

subroutine uscpcl &
!================

 ( nvar   , nscal  ,                                              &
   icodcl , itrifb , itypfb , izfppp ,                            &
   dt     , rtp    , rtpa   , propce , propfa , propfb ,          &
   coefa  , coefb  , rcodcl )

!===============================================================================
! PURPOSE  :
! --------
!    USER'S ROUTINE FOR EXTENDED PHYSIC
!           PULVERISED COAL COMBUSTION
!    ALLOCATION OF BOUNDARY CONDITIONS (ICODCL,RCODCL)
!    FOR VARIABLES UNKNOWN DURING USCLIM
!
! Introduction
! ============

! Here we define boundary conditions on a per-face basis.

! Boundary faces may be identified using the 'getfbr' subroutine.

!  getfbr(string, nelts, eltlst) :
!  - string is a user-supplied character string containing
!    selection criteria;
!  - nelts is set by the subroutine. It is an integer value
!    corresponding to the number of boundary faces verifying the
!    selection criteria;
!  - lstelt is set by the subroutine. It is an integer array of
!    size nelts containing the list of boundary faces verifying
!    the selection criteria.

!  string may contain:
!  - references to colors (ex.: 1, 8, 26, ...
!  - references to groups (ex.: inlet, group1, ...)
!  - geometric criteria (ex. x < 0.1, y >= 0.25, ...)
!  These criteria may be combined using logical operators
!  ('and', 'or') and parentheses.
!  Example: '1 and (group2 or group3) and y < 1' will select boundary
!  faces of color 1, belonging to groups 'group2' or 'group3' and
!  with face center coordinate y less than 1.



! Boundary condition types
! ========================

! Boundary conditions may be assigned in two ways.


!    For "standard" boundary conditions:
!    -----------------------------------

!     (inlet, free outlet, wall, symmetry), we define a code
!     in the 'itypfb' array (of dimensions number of boundary faces,
!     number of phases). This code will then be used by a non-user
!     subroutine to assign the following conditions (scalars in
!     particular will receive the conditions of the phase to which
!     they are assigned). Thus:

!     Code      |  Boundary type
!     --------------------------
!      ientre   |   Inlet
!      isolib   |   Free outlet
!      isymet   |   Symmetry
!      iparoi   |   Wall (smooth)
!      iparug   |   Rough wall

!     Integers ientre, isolib, isymet, iparoi, iparug
!     are defined elsewhere (param.h). Their value is greater than
!     or equal to 1 and less than or equal to ntypmx
!     (value fixed in paramx.h)


!     In addition, some values must be defined:


!     - Inlet (more precisely, inlet/outlet with prescribed flow, as
!              the flow may be prescribed as an outflow):

!       -> Dirichlet conditions on variables
!         other than pressure are mandatory if the flow is incoming,
!         optional if the flow is outgoing (the code assigns 0 flux
!         if no Dirichlet is specified); thus,
!         at face 'ifac', for the variable 'ivar': rcodcl(ifac, ivar, 1)


!     - Smooth wall: (= impermeable solid, with smooth friction)

!       -> Velocity value for sliding wall if applicable
!         at face ifac, rcodcl(ifac, iu, 1)
!                       rcodcl(ifac, iv, 1)
!                       rcodcl(ifac, iw, 1)
!       -> Specific code and prescribed temperature value
!         at wall, if applicable:
!         at face ifac, icodcl(ifac, ivar)    = 5
!                       rcodcl(ifac, ivar, 1) = prescribed temperature
!       -> Specific code and prescribed flux value
!         at wall, if applicable:
!         at face ifac, icodcl(ifac, ivar)    = 3
!                       rcodcl(ifac, ivar, 3) = prescribed flux
!                                        =
!        Note that the default condition for scalars
!         (other than k and epsilon) is homogeneous Neumann.


!     - Rough wall: (= impermeable solid, with rough friction)

!       -> Velocity value for sliding wall if applicable
!         at face ifac, rcodcl(ifac, iu, 1)
!                       rcodcl(ifac, iv, 1)
!                       rcodcl(ifac, iw, 1)
!       -> Value of the dynamic roughness height to specify in
!                       rcodcl(ifac, iu, 3) (value for iv et iw not used)
!       -> Specific code and prescribed temperature value
!         at rough wall, if applicable:
!         at face ifac, icodcl(ifac, ivar)    = 6
!                       rcodcl(ifac, ivar, 1) = prescribed temperature
!                       rcodcl(ifac, ivar, 3) = dynamic roughness height
!       -> Specific code and prescribed flux value
!         at rough wall, if applicable:
!         at face ifac, icodcl(ifac, ivar)    = 3
!                       rcodcl(ifac, ivar, 3) = prescribed flux
!                                        =
!        Note that the default condition for scalars
!         (other than k and epsilon) is homogeneous Neumann.

!     - Symmetry (= impermeable frictionless wall):

!       -> Nothing to specify


!     - Free outlet (more precisely free inlet/outlet with prescribed pressure)

!       -> Nothing to prescribe for pressure and velocity
!          For scalars and turbulent values, a Dirichlet value may optionally
!            be specified. The behavior is as follows:
!              * pressure is always handled as a Dirichlet condition
!              * if the mass flow is inflowing:
!                  we retain the velocity at infinity
!                  Dirichlet condition for scalars and turbulent values
!                    (or zero flux if the user has not specified a
!                    Dirichlet value)
!                if the mass flow is outflowing:
!                  we prescribe zero flux on the velocity, the scalars,
!                  and turbulent values

!       Note that the pressure will be reset to P0
!           on the first free outlet face found


!    For "non-standard" conditions:
!    ------------------------------

!     Other than (inlet, free outlet, wall, symmetry), we define
!      - on one hand, for each face:
!        -> an admissible 'itypfb' value
!           (i.e. greater than or equal to 1 and less than or equal to
!            ntypmx; see its value in paramx.h).
!           The values predefined in paramx.h:
!           'ientre', 'isolib', 'isymet', 'iparoi', 'iparug' are in
!           this range, and it is preferable not to assign one of these
!           integers to 'itypfb' randomly or in an inconsiderate manner.
!           To avoid this, we may use 'iindef' if we wish to avoid
!           checking values in paramx.h. 'iindef' is an admissible
!           value to which no predefined boundary condition is attached.
!           Note that the 'itypfb' array is reinitialized at each time
!           step to the non-admissible value of 0. If we forget to
!           modify 'typfb' for a given face, the code will stop.

!      - and on the other hand, for each face and each variable:
!        -> a code             icodcl(ifac, ivar)
!        -> three real values  rcodcl(ifac, ivar, 1)
!                              rcodcl(ifac, ivar, 2)
!                              rcodcl(ifac, ivar, 3)
!     The value of 'icodcl' is taken from the following:
!       1: Dirichlet      (usable for any variable)
!       3: Neumann        (usable for any variable)
!       4: Symmetry       (usable only for the velocity and
!                          components of the Rij tensor)
!       5: Smooth wall    (usable for any variable except for pressure)
!       6: Rough wall     (usable for any variable except for pressure)
!       9: Free outlet    (usable only for velocity)
!     The values of the 3 'rcodcl' components are
!      rcodcl(ifac, ivar, 1):
!         Dirichlet for the variable          if icodcl(ifac, ivar) =  1
!         wall value (sliding velocity, temp) if icodcl(ifac, ivar) =  5
!         The dimension of rcodcl(ifac, ivar, 1) is that of the
!           resolved variable: ex U (velocity in m/s),
!                                 T (temperature in degrees)
!                                 H (enthalpy in J/kg)
!                                 F (passive scalar in -)
!      rcodcl(ifac, ivar, 2):
!         "exterior" exchange coefficient (between the prescribed value
!                          and the value at the domain boundary)
!                          rinfin = infinite by default
!         For velocities U,                in kg/(m2 s):
!           rcodcl(ifac, ivar, 2) =          (viscl+visct) / d
!         For the pressure P,              in  s/m:
!           rcodcl(ifac, ivar, 2) =                     dt / d
!         For temperatures T,              in Watt/(m2 degres):
!           rcodcl(ifac, ivar, 2) = Cp*(viscls+visct/sigmas) / d
!         For enthalpies H,                in kg /(m2 s):
!           rcodcl(ifac, ivar, 2) =    (viscls+visct/sigmas) / d
!         For other scalars F              in:
!           rcodcl(ifac, ivar, 2) =    (viscls+visct/sigmas) / d
!              (d has the dimension of a distance in m)
!
!      rcodcl(ifac, ivar, 3) if icodcl(ifac, ivar) <> 6:
!        Flux density (< 0 if gain, n outwards-facing normal)
!                         if icodcl(ifac, ivar)= 3
!         For velocities U,                in kg/(m s2) = J:
!           rcodcl(ifac, ivar, 3) =         -(viscl+visct) * (grad U).n
!         For pressure P,                  en kg/(m2 s):
!           rcodcl(ifac, ivar, 3) =                    -dt * (grad P).n
!         For temperatures T,              in Watt/m2:
!           rcodcl(ifac, ivar, 3) = -Cp*(viscls+visct/sigmas) * (grad T).n
!         For enthalpies H,                in Watt/m2:
!           rcodcl(ifac, ivar, 3) = -(viscls+visct/sigmas) * (grad H).n
!         For other scalars F in :
!           rcodcl(ifac, ivar, 3) = -(viscls+visct/sigmas) * (grad F).n

!      rcodcl(ifac, ivar, 3) if icodcl(ifac, ivar) = 6:
!        Roughness for the rough wall law
!         For velocities U, dynamic roughness
!           rcodcl(ifac, ivar, 3) = rugd
!         For other scalars, thermal roughness
!           rcodcl(ifac, ivar, 3) = rugt


!      Note that if the user assigns a value to itypfb equal to
!       ientre, isolib, isymet, iparoi, or iparug
!       and does not modify icodcl (zero value by default),
!       itypfb will define the boundary condition type.

!      To the contrary, if the user prescribes
!        icodcl(ifac, ivar) (nonzero),
!        the values assigned to rcodcl will be used for the considered
!        face and variable (if rcodcl values are not set, the default
!        values will be used for the face and variable, so:
!                                 rcodcl(ifac, ivar, 1) = 0.d0
!                                 rcodcl(ifac, ivar, 2) = rinfin
!                                 rcodcl(ifac, ivar, 3) = 0.d0)
!        Especially, we may have for example:
!        -> set itypfb(ifac) = iparoi
!        which prescribes default wall conditions for all variables at
!        face ifac,
!        -> and define IN ADDITION for variable ivar on this face
!        specific conditions by specifying
!        icodcl(ifac, ivar) and the 3 rcodcl values.


!      The user may also assign to itypfb a value not equal to
!       ientre, isolib, isymet, iparoi, iparug, iindef
!       but greater than or equal to 1 and less than or equal to
!       ntypmx (see values in param.h) to distinguish
!       groups or colors in other subroutines which are specific
!       to the case and in which itypfb is accessible.
!       In this case though it will be necessary to
!       prescribe boundary conditions by assigning values to
!       icodcl and to the 3 rcodcl fields (as the value of itypfb
!       will not be predefined in the code).


! Consistency rules
! =================

!       A few consistency rules between 'icodcl' codes for
!         variables with non-standard boundary conditions:

!           Codes for velocity components must be identical
!           Codes for Rij components must be identical
!           If code (velocity or Rij) = 4
!             we must have code (velocity and Rij) = 4
!           If code (velocity or turbulence) = 5
!             we must have code (velocity and turbulence) = 5
!           If code (velocity or turbulence) = 6
!             we must have code (velocity and turbulence) = 6
!           If scalar code (except pressure or fluctuations) = 5
!             we must have velocity code = 5
!           If scalar code (except pressure or fluctuations) = 6
!             we must have velocity code = 6


! Remarks
! =======

!       Caution: to prescribe a flux (nonzero) to Rij,
!                the viscosity to take into account is viscl
!                even if visct exists (visct=rho cmu k2/epsilon)

!       We have the ordering array for boundary faces from the
!           previous time step (except for the fist time step,
!           where 'itrifb' has not been set yet).
!       The array of boundary face types 'itypfb' has been
!           reset before entering the subroutine.


!       Note how to access some variables:

! Cell values
!               Let         iel = ifabor(ifac)

! * Density                                      cell iel:
!                  propce(iel, ipproc(irom))
! * Dynamic molecular viscosity                  cell iel:
!                  propce(iel, ipproc(iviscl))
! * Turbulent viscosity   dynamique              cell iel:
!                  propce(iel, ipproc(ivisct))
! * Specific heat                                cell iel:
!                  propce(iel, ipproc(icp))
! * Diffusivity: lambda          scalaire iscal, cell iel:
!                  propce(iel, ipproc(ivisls(iscal)))

! Boundary face values

! * Density                                     boundary face ifac :
!                  propfb(ifac, ipprob(irom))
! * Mass flow relative to variable ivar, boundary face ifac:
!      (i.e. the mass flow used for convecting ivar)
!                  propfb(ifac, pprob(ifluma(ivar )))
! * For other values                  at boundary face ifac:
!      take as an approximation the value in the adjacent cell iel
!      i.e. as above with iel = ifabor(ifac).

!-------------------------------------------------------------------------------
! Arguments
!__________________.____._____.________________________________________________.
! name             !type!mode ! role                                           !
!__________________!____!_____!________________________________________________!
! nvar             ! i  ! <-- ! total number of variables                      !
! nscal            ! i  ! <-- ! total number of scalars                        !
! icodcl           ! ia ! --> ! boundary condition code                        !
!  (nfabor, nvar)  !    !     ! = 1  -> Dirichlet                              !
!                  !    !     ! = 2  -> flux density                           !
!                  !    !     ! = 4  -> sliding wall and u.n=0 (velocity)      !
!                  !    !     ! = 5  -> friction and u.n=0 (velocity)          !
!                  !    !     ! = 6  -> roughness and u.n=0 (velocity)         !
!                  !    !     ! = 9  -> free inlet/outlet (velocity)           !
!                  !    !     !         inflowing possibly blocked             !
! itrifb(nfabor    ! ia ! <-- ! indirection for boundary faces ordering)       !
! itypfb           ! ia ! --> ! boundary face types                            !
! dt(ncelet)       ! ra ! <-- ! time step (per cell)                           !
! rtp, rtpa        ! ra ! <-- ! calculated variables at cell centers           !
!  (ncelet, *)     !    !     !  (at current and preceding time steps)         !
! propce(ncelet, *)! ra ! <-- ! physical properties at cell centers            !
! propfa(nfac, *)  ! ra ! <-- ! physical properties at interior face centers   !
! propfb(nfabor, *)! ra ! <-- ! physical properties at boundary face centers   !
! coefa, coefb     ! ra ! <-- ! boundary conditions                            !
!  (nfabor, *)     !    !     !                                                !
! rcodcl           ! ra ! --> ! boundary condition values                      !
!                  !    !     ! rcodcl(1) = Dirichlet value                    !
!                  !    !     ! rcodcl(2) = exterior exchange coefficient      !
!                  !    !     !  (infinite if no exchange)                     !
!                  !    !     ! rcodcl(3) = flux density value                 !
!                  !    !     !  (negative for gain) in w/m2 or                !
!                  !    !     !  roughness height (m) if icodcl=6              !
!                  !    !     ! for velocities           ( vistl+visct)*gradu  !
!                  !    !     ! for pressure                         dt*gradp  !
!                  !    !     ! for scalars    cp*(viscls+visct/sigmas)*gradt  !
!__________________!____!_____!________________________________________________!

!     Type: i (integer), r (real), s (string), a (array), l (logical),
!           and composite types (ex: ra real array)
!     mode: <-- input, --> output, <-> modifies data, --- work array
!===============================================================================

!===============================================================================
! Module files
!===============================================================================

use ihmpre
use paramx
use numvar
use optcal
use cstphy
use cstnum
use entsor
use parall
use period
use ppppar
use ppthch
use coincl
use cpincl
use ppincl
use ppcpfu
use mesh

!===============================================================================

implicit none

! Arguments

integer          nvar   , nscal

integer          icodcl(nfabor,nvar)
integer          itrifb(nfabor), itypfb(nfabor)
integer          izfppp(nfabor)

double precision dt(ncelet), rtp(ncelet,*), rtpa(ncelet,*)
double precision propce(ncelet,*)
double precision propfa(nfac,*), propfb(nfabor,*)
double precision coefa(nfabor,*), coefb(nfabor,*)
double precision rcodcl(nfabor,nvar,3)

! LOCAL VARIABLES

integer          ifac, ii
integer          izone
integer          icha, iclapc
integer          ilelt, nlelt

double precision uref2, d2s3
double precision xkent, xeent

integer, allocatable, dimension(:) :: lstelt

!===============================================================================

! TEST_TO_REMOVE_FOR_USE_OF_SUBROUTINE_START
!===============================================================================
! 0.  THIS TEST CERTIFY THIS VERY ROUTINE IS USED
!     IN PLACE OF LIBRARY'S ONE
!===============================================================================

if (iihmpr.eq.1) then
  return
else
  write(nfecra,9001)
  call csexit (1)
  !==========
endif

 9001 format(                                                           &
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/,&
'@ @@ BEWARE : STOP DURING BOUNDARY CONDITIONS INLET          ',/,&
'@    =========                                               ',/,&
'@     FOR PULVERISED COAL COMBUSTION                         ',/,&
'@     THE USER SUBROUTINE uscpcl HAVE TO BE COMPLETED        ',/,&
'@                                                            ',/,&
'@  The computation will not start                            ',/,&
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/)

! TEST_TO_REMOVE_FOR_USE_OF_SUBROUTINE_END


!===============================================================================
! 1.  INITIALISATIONS
!===============================================================================

! Allocate a temporary array for boundary faces selection
allocate(lstelt(nfabor))


d2s3 = 2.d0/3.d0

!===============================================================================
! 2.  ALLOCATION OF BOUNDARY CONDITIONS VECTOR
!       LOOP ON BOUNDARY FACE
!         FAMILY AND PROPERTIES ARE DETERMINED
!         BOUNDARY CONDITION ALLOCATED
!
!     BOUNDARY CONDITIONS ON BONDARY FACE HAVE TO BE ALLOCATED HERE
!
!     USER'S WORK TO DO
!
!===============================================================================

! ---- BOUNDARY FACE corresponding to AIR INLET
!      e.g. : secondary or tertiary air

CALL GETFBR('12',NLELT,LSTELT)
!==========

do ilelt = 1, nlelt

  ifac = lstelt(ilelt)

!   Kind of boundary conditions for standard variables
  itypfb(ifac) = ientre

!   zone's number (from 1 to n)
  izone = 1

!      - Allocation of the zone's number to the face
  izfppp(ifac) = izone

!      - For theses inlet faces, mass flux is fixed

  ientat(izone) = 1
  iqimp(izone)  = 1
!      - Oxidizer's number (1 to 3)
  inmoxy(izone) = 1
!      - Oxidizer mass flow rate  in kg/s
  qimpat(izone) = 1.46d-03
!      - Oxidizer's Temperature in K
  timpat(izone) = 400.d0 + tkelvi

!      - The color 12 becomes an fixed flow rate inlet
!        The user gives speed vector direction
!        (speed vector norm is irrelevent)

  rcodcl(ifac,iu,1) = 0.d0
  rcodcl(ifac,iv,1) = 0.d0
  rcodcl(ifac,iw,1) = 5.d0

! ------ Turbulence treatment
!   Boundary conditions of turbulence
  icalke(izone) = 1
!
!    - If ICALKE = 0 the boundary conditions of turbulence at
!      the inlet are calculated as follows:

  if(icalke(izone).eq.0) then

    uref2 = rcodcl(ifac,iu,1)**2                           &
           +rcodcl(ifac,iv,1)**2                           &
           +rcodcl(ifac,iw,1)**2
    uref2 = max(uref2,1.d-12)
    xkent  = epzero
    xeent  = epzero

    call keenin                                                   &
    !==========
      ( uref2, xintur(izone), dh(izone), cmu, xkappa,             &
        xkent, xeent )

    if    (itytur.eq.2) then

      rcodcl(ifac,ik,1)  = xkent
      rcodcl(ifac,iep,1) = xeent

    elseif(itytur.eq.3) then

      rcodcl(ifac,ir11,1) = d2s3*xkent
      rcodcl(ifac,ir22,1) = d2s3*xkent
      rcodcl(ifac,ir33,1) = d2s3*xkent
      rcodcl(ifac,ir12,1) = 0.d0
      rcodcl(ifac,ir13,1) = 0.d0
      rcodcl(ifac,ir23,1) = 0.d0
      rcodcl(ifac,iep,1)  = xeent

    elseif (iturb.eq.50) then

      rcodcl(ifac,ik,1)   = xkent
      rcodcl(ifac,iep,1)  = xeent
      rcodcl(ifac,iphi,1) = d2s3
      rcodcl(ifac,ifb,1)  = 0.d0

    elseif (iturb.eq.60) then

      rcodcl(ifac,ik,1)   = xkent
      rcodcl(ifac,iomg,1) = xeent/cmu/xkent

    elseif (iturb.eq.70) then

      rcodcl(ifac,inusa,1) = cmu*xkent**2/xeent

    endif

  endif
!
!    - If ICALKE = 1 the boundary conditions of turbulence at
!      the inlet refer to both, a hydraulic diameter and a
!      reference velocity given in usini1.f90.
!
  dh(izone)     = 0.032d0
!
!    - If ICALKE = 2 the boundary conditions of turbulence at
!      the inlet refer to a turbulence intensity.
!
  xintur(izone) = 0.d0

! ------ Automatic treatment of scalars for extended physic


! ------ treatment of user's scalars

  if ( (nscal-nscapp).gt.0 ) then
    do ii = 1, (nscal-nscapp)
      rcodcl(ifac,isca(ii),1) = 1.d0
    enddo
  endif

enddo

! ---- BOUNDARY FACE for pulverised COAL & primary air INLET

CALL GETFBR('11',NLELT,LSTELT)
!==========

do ilelt = 1, nlelt

  ifac = lstelt(ilelt)

!   Kind of boundary conditions for standard variables
  itypfb(ifac) = ientre

!   zone's number (from 1 to n)
  izone = 2

!      - Allocation of the zone's number to the face
  izfppp(ifac) = izone

!      - For theses inlet faces, mass flux is fixed

  ientcp(izone) = 1
  iqimp(izone)  = 1
!      - Oxidizer's number (1 to 3)
  inmoxy(izone) = 1
!      - Oxidizer's mass flow rate in kg/s
  qimpat(izone) = 1.46d-03
!      - Oxidizer's Temperature in K
  timpat(izone) = 800.d0  + tkelvi

!        Coal inlet, initialisation
  do icha = 1, ncharm
    qimpcp(izone,icha) = zero
    timpcp(izone,icha) = zero
    do iclapc = 1, ncpcmx
      distch(izone,icha,iclapc) = zero
    enddo
  enddo

! Code_Saturne deals with NCHA different coals (component of blend)
!       every coal is described by NCLPCH(icha) class of particles
!       (each of them described by an inlet diameter)
!
!      - Treatment for the first coal
  icha = 1
!      - Coal mass flow rate in kg/s
   qimpcp(izone,icha) = 1.46d-4
!      - PERCENTAGE mass fraction of each granulometric class
  do iclapc = 1, nclpch(icha)
    distch(izone,icha,iclapc) = 100.d0/dble(nclpch(icha))
  enddo
!      - Inlet temperature for coal & primary air
  timpcp(izone,icha) = 800.d0 + tkelvi

!      - The color 11 becomes an fixed flow rate inlet
!        The user gives speed vector direction
!        (speed vector norm is irrelevent)

  rcodcl(ifac,iu,1) = 0.d0
  rcodcl(ifac,iv,1) = 0.d0
  rcodcl(ifac,iw,1) = 5.d0

! PPl
! ------ Traitement de la turbulence

!        La turbulence est calculee par defaut si ICALKE different de 0
!          - soit a partir du diametre hydraulique, d'une vitesse
!            de reference adaptes a l'entree courante si ICALKE = 1
!          - soit a partir du diametre hydraulique, d'une vitesse
!            de reference et de l'intensite turvulente
!            adaptes a l'entree courante si ICALKE = 2

!      Choix pour le calcul automatique ICALKE = 1 ou 2
  icalke(izone) = 1
!      Saisie des donnees
  dh(izone)     = 0.1d0
  xintur(izone) = 0.1d0

! PPl
!
enddo

!     The color 15 become a WALL

CALL GETFBR('15',NLELT,LSTELT)
!==========

do ilelt = 1, nlelt

  ifac = lstelt(ilelt)

!          WALL : NUL MASS FLUX (PRESSURE FLUX is zero valued)
!                 FRICTION FOR SPEED (& TURBULENCE)
!                 NUL SCALAR FLUX

!   Kind of boundary conditions for standard variables
  itypfb(ifac)   = iparoi


!   zone's number (from 1 to n)
  izone = 3

!      - Allocation of the zone's number to the face
  izfppp(ifac) = izone

enddo


!     The color 19 becomes an OUTLET

CALL GETFBR('19',NLELT,LSTELT)
!==========

do ilelt = 1, nlelt

  ifac = lstelt(ilelt)

!          OUTLET : NUL FLUX for SPEED & SCALARS, FIXED PRESSURE

!   Kind of boundary conditions for standard variables
  itypfb(ifac)   = isolib

!   zone's number (from 1 to n)
  izone = 4

!      - Allocation of the zone's number to the face
  izfppp(ifac) = izone

enddo

!     The color 14 becomes a symetry plane

CALL GETFBR('14 or 4',NLELT,LSTELT)
!==========

do ilelt = 1, nlelt

  ifac = lstelt(ilelt)

!          SYMETRIES

!   Kind of boundary conditions for standard variables
  itypfb(ifac)   = isymet

!   zone's number (from 1 to n)
  izone = 5

!      - Allocation of the zone's number to the face
  izfppp(ifac) = izone

enddo


!----
! END
!----

! Deallocate the temporary array
deallocate(lstelt)

return
end subroutine
