!-------------------------------------------------------------------------------

! This file is part of Code_Saturne, a general-purpose CFD tool.
!
! Copyright (C) 1998-2014 EDF S.A.
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

!> \file varpos.f90
!> \brief Variables location initialization, according to calculation type
!> selected by the user.
!>
!------------------------------------------------------------------------------

!------------------------------------------------------------------------------
! Arguments
!------------------------------------------------------------------------------
!   mode          name          role
!------------------------------------------------------------------------------
!______________________________________________________________________________

subroutine varpos

!===============================================================================
! Module files
!===============================================================================

use paramx
use dimens
use numvar
use optcal
use cstphy
use cstnum
use entsor
use albase
use lagpar
use lagdim
use lagran
use parall
use ppppar
use ppthch
use coincl
use cpincl
use ppincl
use radiat
use ihmpre
use mesh
use field
use cs_c_bindings

!===============================================================================

implicit none

! Arguments

! Local variables

integer       iscal , iprop, id, f_dim, ityloc, itycat
integer       ii    , jj
integer       iok   , ippok
integer       ivisph
integer       imom  , idgmom, mom_id
integer       idffin, idfmji
integer       inmfin
integer       nprmax
integer       idttur

double precision gravn2

character(len=80) :: f_label, f_name, s_label, s_name
integer(c_int), dimension(ndgmox) :: mom_f_id, mom_c_id

!===============================================================================
! 0. INITIALISATIONS
!===============================================================================

! Initialize variables to avoid compiler warnings
ippok = 0

!===============================================================================
! 1. POSITIONNEMENT DES PROPRIETES POUR LE SCHEMA EN TEMPS,
!                                       LES MOMENTS ET FIN
!===============================================================================

! Dans le cas ou on a un schema en temps d'ordre 2, il faut aussi
!   prevoir les proprietes au temps n-1. Ce sera fait au dernier appel

! Dans le cas ou on calcule des moments, il faut en prevoir le nombre
!   et prevoir le nombre de tableaux necessaires pour stocker le
!   temps cumule de moyenne. On suppose que l'on peut s'aider
!   d'infos situees en tete de fichier suite (si on fait une
!   suite avec des moments non reinitialises).

! 1.1 PROPRIETES ADDITIONNELLES POUR LES ET SCHEMA EN TEMPS
! ---------------------------------------------------------

! Initialisations par defaut eventuelles et verifications
!   des options utilisees ci-dessous pour decider si l'on
!   reserve des tableaux supplementaires pour des grandeurs
!   au pas de temps precedent

iok = 0

!  Pression hydrostatique
if (iphydr.eq.0.or.iphydr.eq.2) then
  icalhy = 0
else if (iphydr.eq.1) then
  gravn2 = gx**2+gy**2+gz**2
  if (gravn2.lt.epzero**2) then
    icalhy = 0
  else
    icalhy = 1
  endif
endif

!   Schemas en temps
!       en LES : Ordre 2 ; sinon Ordre 1
!       (en particulier, ordre 2 impossible en k-eps couple)
if (ischtp.eq.-999) then
  if (itytur.eq.4) then
    ischtp = 2
  else
    ischtp = 1
  endif
endif

!   Schemas en temps : variables deduites
!   Schema pour le Flux de masse
if (istmpf.eq.-999) then
  if (ischtp.eq.1) then
    istmpf = 1
  else if (ischtp.eq.2) then
    istmpf = 2
  endif
endif
!     Masse volumique
if (iroext.eq.-999) then
  if (ischtp.eq.1) then
    iroext = 0
  else if (ischtp.eq.2) then
    !       Pour le moment par defaut on ne prend pas l'ordre 2
    !              IROEXT = 1
    iroext = 0
  endif
endif
!     Viscosite
if (iviext.eq.-999) then
  if (ischtp.eq.1) then
    iviext = 0
  else if (ischtp.eq.2) then
    !       Pour le moment par defaut on ne prend pas l'ordre 2
    !              IVIEXT = 1
    iviext = 0
  endif
endif
!     Chaleur massique
if (icpext.eq.-999) then
  if (ischtp.eq.1) then
    icpext = 0
  else if (ischtp.eq.2) then
    !       Pour le moment par defaut on ne prend pas l'ordre 2
    !              ICPEXT = 1
    icpext = 0
  endif
endif
!     Termes sources NS,
if (isno2t.eq.-999) then
  if (ischtp.eq.1) then
    isno2t = 0
    !            ELSE IF (ISCHTP.EQ.2.AND.IVISSE.EQ.1) THEN
  else if (ischtp.eq.2) then
    !       Pour le moment par defaut on prend l'ordre 2
    isno2t = 1
    !              ISNO2T = 0
  endif
endif
!     Termes sources turbulence (k-eps, Rij, v2f ou k-omega)
!     On n'autorise de changer ISTO2T qu'en Rij (sinon avec
!       le couplage k-eps/omega il y a pb)
if (isto2t.eq.-999) then
  if (ischtp.eq.1) then
    isto2t = 0
  else if (ischtp.eq.2) then
    !       Pour le moment par defaut on ne prend pas l'ordre 2
    !              ISTO2T = 1
    isto2t = 0
  endif
else if (itytur.eq.2.or.iturb.eq.50.or.iturb.ne.60) then
  write(nfecra,8132) iturb,isto2t
  iok = iok + 1
endif

idttur = 0

do iscal = 1, nscal
  ! Termes sources Scalaires,
  if (isso2t(iscal).eq.-999) then
    if (ischtp.eq.1) then
      isso2t(iscal) = 0
    else if (ischtp.eq.2) then
      ! Pour coherence avec Navier Stokes on prend l'ordre 2
      ! mais de toute facon qui dit ordre 2 dit LES et donc
      ! generalement pas de TS scalaire a interpoler.
      isso2t(iscal) = 1
    endif
  endif
  ! Diffusivite scalaires
  if (ivsext(iscal).eq.-999) then
    if (ischtp.eq.1) then
      ivsext(iscal) = 0
    else if (ischtp.eq.2) then
      ! Pour le moment par defaut on ne prend pas l'ordre 2
      ivsext(iscal) = 0
    endif
  endif

  ! Model for turbulent fluxes u'T' (SGDH, GGDH, AFM, DFM)
  ityturt(iscal) = iturt(iscal)/10

  ! Index of the turbulent flux
  if (ityturt(iscal).eq.3) then
    idttur = idttur + 1
    ifltur(iscal) = idttur
  endif

enddo

! Pression hydrostatique
if (iphydr.ne.0.and.iphydr.ne.1.and.iphydr.ne.2) then
  write(nfecra,8121) 'IPHYDR ',iphydr
  iok = iok + 1
endif

! Viscosite secondaire
ivisph = ivisse
if (ivisph.ne.0.and.ivisph.ne.1) then
  write(nfecra,8022) 'IVISSE ',ivisph
  iok = iok + 1
endif

! Schemas en temps

!     Schema en temps global.
if (ischtp.ne. 1.and.ischtp.ne.2) then
  write(nfecra,8101) 'ISCHTP',ischtp
  iok = iok + 1
endif
if (ischtp.eq. 2.and.idtvar.ne.0) then
  write(nfecra,8111) ischtp,idtvar
  iok = iok + 1
endif
if (ischtp.eq. 2.and.itytur.eq.2) then
  write(nfecra,8112) ischtp,iturb
  iok = iok + 1
endif
if (ischtp.eq.1.and.itytur.eq.4) then
  write(nfecra,8113) ischtp,iturb
endif
if (ischtp.eq. 2.and.iturb.eq.50) then
  write(nfecra,8114) ischtp,iturb
  iok = iok + 1
endif
if (ischtp.eq. 2.and.iturb.eq.51) then
  write(nfecra,8117) ischtp,iturb
  iok = iok + 1
endif
if (ischtp.eq. 2.and.iturb.eq.60) then
  write(nfecra,8115) ischtp,iturb
  iok = iok + 1
endif
if (ischtp.eq. 2.and.iturb.eq.70) then
  write(nfecra,8116) ischtp,iturb
  iok = iok + 1
endif

! Schema en temps pour le flux de masse
if (istmpf.ne. 2.and.istmpf.ne.0.and.istmpf.ne. 1) then
  write(nfecra,8121) 'ISTMPF',istmpf
  iok = iok + 1
endif

! Schema en temps pour les termes sources de NS
if (isno2t.ne.0.and.isno2t.ne. 1.and.isno2t.ne.2) then
  write(nfecra,8131) 'ISNO2T',isno2t
  iok = iok + 1
endif
! Schema en temps pour les termes sources des grandeurs turbulentes
if (isto2t.ne.0.and.isto2t.ne. 1.and.isto2t.ne.2) then
  write(nfecra,8131) 'ISTO2T',isto2t
  iok = iok + 1
endif

! Schema en temps pour la masse volumique
if (iroext.ne.0.and.iroext.ne. 1.and.iroext.ne.2) then
  write(nfecra,8131) 'IROEXT',iroext
  iok = iok + 1
endif

! Schema en temps pour la viscosite
if (iviext.ne.0.and.iviext.ne. 1.and.iviext.ne.2) then
  write(nfecra,8131) 'IVIEXT',iviext
  iok = iok + 1
endif

! Schema en temps pour la chaleur specifique
if (icpext.ne.0 .and. icpext.ne.1 .and.icpext.ne.2) then
  write(nfecra,8131) 'ICPEXT',icpext
  iok = iok + 1
endif

do iscal = 1, nscal
  ! Schema en temps pour les termes sources des scalaires
  if (isso2t(iscal).ne.0.and.                                    &
      isso2t(iscal).ne. 1.and.isso2t(iscal).ne.2) then
    write(nfecra,8141) iscal,'ISSO2T',isso2t(iscal)
    iok = iok + 1
  endif
  ! Schema en temps pour la viscosite
  if (ivsext(iscal).ne.0.and.                                    &
      ivsext(iscal).ne. 1.and.ivsext(iscal).ne.2) then
    write(nfecra,8141) iscal,'IVSEXT',ivsext(iscal)
    iok = iok + 1
  endif
enddo

! Stop si probleme
if (iok.gt.0) then
  call csexit(1)
endif

! Numeros de propriete

nprmax = nproce

! Source term for weakly compressible algorithm (semi analytic scheme)
if (idilat.eq.4) then
  do iscal = 1, nscal
    id = ivarfl(isca(iscal))
    call field_get_name(id, s_name)
    call field_get_label(id, s_label)
    f_name  = trim(s_name) // '_dila_st'
    call add_property_field(f_name, '', iustdy(iscal))
    id = iprpfl(iustdy(iscal))
    call field_set_key_int(id, keyipp, -1)
    call field_set_key_int(id, keyvis, 0)
  enddo
  itsrho = nscal + 1
  call add_property_field('dila_st', '', iustdy(itsrho))
  id = iprpfl(iustdy(iscal))
  call field_set_key_int(id, keyipp, -1)
  call field_set_key_int(id, keyvis, 0)
endif

! The density at the previous time step is required if idilat>1 or if
! we perform a hydrostatic pressure correction (icalhy=1)
if (iroext.gt.0.or.icalhy.eq.1.or.idilat.gt.1.or.ippmod(icompf).ge.0) then
  nproce = nproce + 1
  iroma  = nproce
  call field_set_n_previous(iprpfl(irom), 1)
endif
! Dans le cas d'une extrapolation de la viscosite totale
if (iviext.gt.0) then
  nproce = nproce + 1
  ivisla = nproce
  call field_set_n_previous(iprpfl(iviscl), 1)
  nproce = nproce + 1
  ivista = nproce
  call field_set_n_previous(iprpfl(ivisct), 1)
endif

! CP s'il est variable
if (icp.ne.0) then
  if (icpext.gt.0) then
    nproce = nproce + 1
    icpa   = nproce
    call field_set_n_previous(iprpfl(icp), 1)
  endif
endif

! On a besoin d'un tableau pour les termes sources de Navier Stokes
!  a extrapoler. Ce tableau est NDIM
if (isno2t.gt.0) then
  call add_property_field_nd('navier_stokes_st_prev', '', 3, itsnsa)
endif

if (isto2t.gt.0) then
  ! The dimension of this array depends on turbulence model:
  if (itytur.eq.2) then
    f_dim = 2
  else if (itytur.eq.3) then
    f_dim = 7
    if (iturb.eq.32) then
      f_dim = 8
    endif
  else if (iturb.eq.50) then
    f_dim = 4
  else if (iturb.eq.70) then
    f_dim = 1
  endif
  call add_property_field_nd('turbulence_st_prev', '', f_dim, itstua)
endif

! Proprietes des scalaires : termes sources pour theta schema
!   et VISCLS si elle est variable
if (nscal.ge.1) then
  do ii = 1, nscal
    if (isso2t(ii).gt.0) then
      call field_get_name(ivarfl(isca(ii)), s_name)
      f_name = trim(s_name) // '_st_prev'
      call add_property_field(f_name, '', itssca(ii))
      call hide_property(itssca(ii))
    endif
    if (ivisls(ii).ne.0) then
      if (ivsext(ii).gt.0) then
        if (iscavr(ii).le.0) then
          nproce = nproce + 1
          ivissa(ii) = nproce
          call field_set_n_previous(iprpfl(ivissa(ii)), 1)
        else if (iscavr(ii).gt.0.and.iscavr(ii).le.nscal) then
          ivissa(ii) = ivissa(iscavr(ii))
        endif
      endif
    endif
  enddo
endif

!===============================================================================
! 2. POSITIONNEMENT DES PROPRIETES POUR LES MOMENTS
!===============================================================================

! 2.2 CALCUL DE LA TAILLE DU TABLEAU DES TEMPS CUMULES POUR LES MOMENTS
! ---------------------------------------------------------------------

! Pour verification des definitions de moments
iok = 0

! Calcul du nombre de moments definis (et verif qu'il n y a pas de trous)
nbmomt = 0
inmfin = 0
do imom = 1, nbmomx
  ! Si on n'est pas a la fin de la liste
  if (inmfin.eq.0) then
    ! Si il y en a, ca en fait en plus
    if (idfmom(1,imom).ne.0) then
      nbmomt = nbmomt + 1
      ! Si il n'y en a pas, c'est la fin de la liste
    else
      inmfin = 1
    endif
    ! Si on est a la fin de la liste, il n'en faut plus
  else
    if (idfmom(1,imom).ne.0) then
      iok = iok + 1
    endif
  endif
enddo

if (iok.ne.0) then
  write(nfecra,8200)nbmomt+1,idfmom(1,nbmomt+1),nbmomt,nbmomt
  do imom = 1, nbmomx
    write(nfecra,8201)imom,idfmom(1,imom)
  enddo
  write(nfecra,8202)
endif

! Verification de IDFMOM
iok = 0
do imom = 1, nbmomx
  idffin = 0
  do jj = 1, ndgmox
    idfmji = idfmom(jj,imom)
    if (idffin.eq.0) then
      if (idfmji.lt.-nprmax) then
        iok = iok + 1
        write(nfecra,8210)jj,imom,idfmji,nprmax
      else if (idfmji.gt.nvar) then
        iok = iok + 1
        write(nfecra,8211)jj,imom,idfmji,nvar
      else if (idfmji.lt.0) then
        if (ipproc(-idfmji).le.0) then
          iok = iok + 1
          write(nfecra,8212)jj,imom,idfmji,-idfmji,ipproc(-idfmji)
        endif
      else if (idfmji.eq.0) then
        idffin = 1
      endif
    else
      if (idfmji.ne.0) then
        iok = iok + 1
        write(nfecra,8213)imom,jj,idfmji
      endif
    endif
  enddo
enddo

if (iok.ne.0) then
  call csexit(1)
endif


! 2.3 POSITIONNEMENT DANS PROPCE DES MOMENTS
! ------------------------------------------

! Reprise du dernier NPROCE (PROPCE et POST-TRAITEMENT)
iprop                 = nproce

! Positionnement

do imom = 1, nbmomt

  write(f_name, '(a, i3.3)') 'moment_', imom
  write(f_label, '(a, i2.2)') 'TemporalMean', imom

  idgmom = 0
  do ii = 1, ndgmox
    if (idfmom(ii,imom).ne.0) then
      idgmom = idgmom + 1
      mom_c_id(idgmom) = 0
      if (idfmom(ii,imom).gt.0) then
        mom_f_id(idgmom) = ivarfl(idfmom(ii,imom))
        jj = idfmom(ii,imom)
        if (jj.gt.1) then
          do while (jj.gt.1 .and. ivarfl(jj-1).eq.ivarfl(idfmom(ii,imom)))
            jj = jj-1
            mom_c_id(idgmom) = mom_c_id(idgmom) + 1
          enddo
        endif
      else if (idfmom(ii,imom).lt.0) then
        mom_f_id(idgmom) = iprpfl(-idfmom(ii,imom))
      endif
    endif
  enddo

  call time_moment_define_by_field_ids(f_name, idgmom,                    &
                                       mom_f_id, mom_c_id,                &
                                       0, ntdmom(imom), ttdmom(imom),     &
                                       imoold(imom), mom_id)
  call time_moment_field_id(mom_id, id)

  call field_set_key_int(id, keyvis, 1)
  call field_set_key_int(id, keylog, 1)
  call field_set_key_str(id, keylbl, trim(f_label))

  ! Property number and mapping to field

  iprop = nproce + 1
  nproce = nproce + 1

  call fldprp_check_nproce

  iprpfl(iprop) = id
  ipproc(iprop) = iprop
  icmome(imom) = iprop

  ! Postprocessing slots

  ipppro(iprop) = nvpp + 1
  nvpp = nvpp + 1

  call field_set_key_int(id, keyipp, ipppro(iprop))

enddo


! 2.4 POINTEURS POST-PROCESSING / LISTING / HISTORIQUES / CHRONOS
! ---------------------------------------------------------------

! Les pointeurs ont ete initialises a 1 (poubelle) dans iniini.

! On posttraitera les variables localisees au centre des cellules.

! ipppro(ipproc(ii)) pour propce a ete complete plus haut
! au fur et a mesure (voir ppprop en particulier)

! Le rang de la derniere propriete pour le post est IPPPST.

! Local time step

ityloc = 1 ! cells
itycat = FIELD_INTENSIVE

call field_create('dt', itycat, ityloc, 1, .true., .false., id)
call field_set_key_str(id, keylbl, 'Local Time Step')
if (idtvar.gt.0) then
  if (idtvar.eq.2) then
    call field_set_key_int(id, keylog, 1)
    call field_set_key_int(id, keyvis, 1)
  endif
  ippdt = nvpp + 1
  nvpp = nvpp + 1
  call field_set_key_int(id, keyipp, ippdt)
endif

itycat = FIELD_INTENSIVE

! Transient velocity/pressure coupling, postprocessing field
! (variant used for computation is a tensorial field, not this one)

if (ipucou.ne.0 .or. ncpdct.gt.0) then
  call field_create('dttens', itycat, ityloc, 6, .true., .false., idtten)
  call field_set_key_int(idtten, keyvis, 1)
  call field_set_key_int(idtten, keylog, 1)
  ipptx = nvpp + 1
  ippty = nvpp + 2
  ipptz = nvpp + 3
  nvpp  = nvpp + 3
  call field_set_key_int(idtten, keyipp, ipptx)
endif

! Verification de la limite sur NVPP

if (nvpp.gt.nvppmx) then
  write(nfecra,8900)nvpp,nvppmx
  call csexit (1)
  !==========
endif

return

!===============================================================================
! 4. Formats
!===============================================================================

#if defined(_CS_LANG_FR)

 8022 format(                                                     &
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/,&
'@ @@ ATTENTION : ARRET A L''ENTREE DES DONNEES               ',/,&
'@    =========                                               ',/,&
'@    ',A6,' DOIT ETRE UN ENTIER EGAL A 0 OU 1                ',/,&
'@    IL VAUT ICI ',I10                                        ,/,&
'@                                                            ',/,&
'@  Le calcul ne peut etre execute.                           ',/,&
'@                                                            ',/,&
'@  Verifier les parametres.                                  ',/,&
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/)
 8101 format(                                                     &
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/,&
'@ @@ ATTENTION : ARRET A L''ENTREE DES DONNEES               ',/,&
'@    =========                                               ',/,&
'@    ',A6,' DOIT ETRE UN ENTIER EGAL A 1 ou 2                ',/,&
'@    IL VAUT ICI ',I10                                        ,/,&
'@                                                            ',/,&
'@  Le calcul ne peut etre execute.                           ',/,&
'@                                                            ',/,&
'@  Verifier les parametres.                                  ',/,&
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/)
 8111 format(                                                     &
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/,&
'@ @@ ATTENTION : ARRET A L''ENTREE DES DONNEES'               ,/,&
'@    =========                                               ',/,&
'@    AVEC UN SCHEMA EN TEMPS D ORDRE 2 : ISCHTP = ', I10      ,/,&
'@    IL FAUT UTILISER UN PAS DE TEMPS CONSTANT ET UNIFORME   ',/,&
'@    OR IDTVAR = ',I10                                        ,/,&
'@                                                            ',/,&
'@  Le calcul ne sera pas execute.                            ',/,&
'@                                                            ',/,&
'@  Verifier les parametres.                                  ',/,&
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/)
 8112 format(                                                     &
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/,&
'@ @@ ATTENTION : ARRET A L''ENTREE DES DONNEES'               ,/,&
'@    =========                                               ',/,&
'@    ON IMPOSE UN SCHEMA EN TEMPS D ORDRE 2 (ISCHTP = ',I10   ,/,&
'@    EN K-EPSILON (ITURB = ',I10,' )'                         ,/,&
'@                                                            ',/,&
'@   La version courante ne supporte pas l ordre 2 avec le    ',/,&
'@   couplage des termes sources du k-epsilon.                ',/,&
'@                                                            ',/,&
'@  Le calcul ne sera pas execute.                            ',/,&
'@                                                            ',/,&
'@  Modifier les parametres.                                  ',/,&
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/)
 8113 format(                                                     &
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/,&
'@ @@ ATTENTION :       A L''ENTREE DES DONNEES'               ,/,&
'@    =========                                               ',/,&
'@    ON IMPOSE UN SCHEMA EN TEMPS D ORDRE 1 (ISCHTP = ',I10   ,/,&
'@    EN LES (ITURB = ',I10,' )'                               ,/,&
'@                                                            ',/,&
'@  Le calcul sera execute.                                   ',/,&
'@                                                            ',/,&
'@  Il est conseille de verifier les parametres.              ',/,&
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/)
 8114 format(                                                     &
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/,&
'@ @@ ATTENTION : ARRET A L''ENTREE DES DONNEES'               ,/,&
'@    =========                                               ',/,&
'@    ON IMPOSE UN SCHEMA EN TEMPS D ORDRE 2 (ISCHTP = ',I10   ,/,&
'@    EN PHI_FBAR (ITURB = ',I10,' )'                          ,/,&
'@                                                            ',/,&
'@   La version courante ne supporte pas l''ordre 2 avec le   ',/,&
'@   couplage des termes sources du k-epsilon.                ',/,&
'@                                                            ',/,&
'@  Le calcul ne sera pas execute.                            ',/,&
'@                                                            ',/,&
'@  Modifier les parametres.                                  ',/,&
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/)
 8117 format(                                                     &
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/,&
'@ @@ ATTENTION : ARRET A L''ENTREE DES DONNEES               ',/,&
'@    =========                                               ',/,&
'@    ON IMPOSE UN SCHEMA EN TEMPS D ORDRE 2 (ISCHTP = ',I10   ,/,&
'@    EN BL-V2/K  (ITURB = ',I10,' )'                         ,/,&
'@                                                            ',/,&
'@   La version courante ne supporte pas l''ordre 2 avec le   ',/,&
'@   couplage des termes sources du k-epsilon.                ',/,&
'@                                                            ',/,&
'@  Le calcul ne sera pas execute.                            ',/,&
'@                                                            ',/,&
'@  Modifier les parametres.                                  ',/,&
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/)
 8115 format(                                                     &
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/,&
'@ @@ ATTENTION : ARRET A L''ENTREE DES DONNEES'               ,/,&
'@    =========                                               ',/,&
'@    ON IMPOSE UN SCHEMA EN TEMPS D ORDRE 2 (ISCHTP = ',I10   ,/,&
'@    EN K-OMEGA   (ITURB = ',I10,' )'                         ,/,&
'@                                                            ',/,&
'@   La version courante ne supporte pas l''ordre 2 avec le   ',/,&
'@   couplage des termes sources du k-omega.                  ',/,&
'@                                                            ',/,&
'@  Le calcul ne sera pas execute.                            ',/,&
'@                                                            ',/,&
'@  Modifier les parametres.                                  ',/,&
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/)
 8116 format(                                                     &
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/,&
'@ @@ ATTENTION : ARRET A L''ENTREE DES DONNEES'               ,/,&
'@    =========                                               ',/,&
'@    ON IMPOSE UN SCHEMA EN TEMPS D ORDRE 2 (ISCHTP = ',I10   ,/,&
'@    EN SPALART   (ITURB = ',I10,' )'                         ,/,&
'@                                                            ',/,&
'@   La version courante ne supporte pas l''ordre 2 avec le   ',/,&
'@   couplage des termes sources de Spalart-Allmaras.         ',/,&
'@                                                            ',/,&
'@  Le calcul ne sera pas execute.                            ',/,&
'@                                                            ',/,&
'@  Modifier les parametres.                                  ',/,&
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/)
 8121 format(                                                     &
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/,&
'@ @@ ATTENTION : ARRET A L''ENTREE DES DONNEES'               ,/,&
'@    =========                                               ',/,&
'@    ',A6,' DOIT ETRE UN ENTIER EGAL A  0, 1 OU 2            ',/,&
'@    IL VAUT ICI ',I10                                        ,/,&
'@                                                            ',/,&
'@  Le calcul ne peut etre execute.                           ',/,&
'@                                                            ',/,&
'@  Verifier les parametres.                                  ',/,&
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/)
 8131 format(                                                     &
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/,&
'@ @@ ATTENTION : ARRET A L''ENTREE DES DONNEES'               ,/,&
'@    =========                                               ',/,&
'@    ',A6,' DOIT ETRE UN ENTIER EGAL A 0, 1 OU 2             ',/,&
'@    IL VAUT ICI ',I10                                        ,/,&
'@                                                            ',/,&
'@  Le calcul ne peut etre execute.                           ',/,&
'@                                                            ',/,&
'@  Verifier les parametres.                                  ',/,&
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/)
 8132 format(                                                     &
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/,&
'@ @@ ATTENTION : ARRET A L''ENTREE DES DONNEES'               ,/,&
'@    =========                                               ',/,&
'@                                                            ',/,&
'@  Avec le modele de turbulence choisi, ITURB = ',I10         ,/,&
'@    la valeur de ISTO2T (extrapolation des termes sources   ',/,&
'@    pour les variables turbulentes) ne doit pas etre modifie',/,&
'@    or ISTO2T a ete force a ',I10                            ,/,&
'@                                                            ',/,&
'@  Le calcul ne sera pas execute.                            ',/,&
'@                                                            ',/,&
'@  Verifier les parametres.                                  ',/,&
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/)
 8141 format(                                                     &
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/,&
'@ @@ ATTENTION : ARRET A L''ENTREE DES DONNEES SCALAIRE ',I10 ,/,&
'@    =========                                               ',/,&
'@    ',A6,' DOIT ETRE UN ENTIER EGAL A 0, 1 OU 2             ',/,&
'@    IL VAUT ICI ',I10                                        ,/,&
'@                                                            ',/,&
'@  Le calcul ne peut etre execute.                           ',/,&
'@                                                            ',/,&
'@  Verifier les parametres.                                  ',/,&
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/)
 8200 format(                                                     &
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/,&
'@ @@ ATTENTION : ARRET A LA VERIFICATION DES DONNEES         ',/,&
'@    =========                                               ',/,&
'@      SUR LA LISTE DES MOYENNES TEMPORELLES                 ',/,&
'@                                                            ',/,&
'@    La valeur de IDFMOM(1,',I10   ,' est ',I10               ,/,&
'@      ceci indique que l''on a defini ',I10   ,' moyennes   ',/,&
'@      temporelles en renseignant les IMOM = ',I10            ,/,&
'@      premieres cases du tableau IDFMOM(.,IMOM).            ',/,&
'@    Les cases suivantes devraient etre nulles.              ',/,&
'@                                                            ',/,&
'@    Ce n''est cependant pas le cas :                        ',/,&
'@                                                            ',/,&
'@        IMOM    IDFMOM(1,IMOM)                              ',/,&
'@  ----------------------------                              '  )
 8201 format(                                                     &
'@  ',I10   ,'        ',     I10                                 )
 8202 format(                                                     &
'@  ----------------------------                              ',/,&
'@                                                            ',/,&
'@    Le calcul ne sera pas  execute.                         ',/,&
'@                                                            ',/,&
'@    Verifier les parametres.                                ',/,&
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/)
 8210 format(                                                     &
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/,&
'@ @@ ATTENTION : ARRET A LA VERIFICATION DES DONNEES         ',/,&
'@    =========                                               ',/,&
'@      SUR LES VARIABLES COMPOSANT LES MOYENNES TEMPORELLES  ',/,&
'@                                                            ',/,&
'@    IDFMOM(',I10   ,',',I10   ,') = ',I10                    ,/,&
'@      Les valeurs negatives renvoient a des proprietes      ',/,&
'@      physiques, or il n y en a que NPRMAX = ', I10          ,/,&
'@    La valeur de IDFMOM est donc erronee.                   ',/,&
'@                                                            ',/,&
'@    Le calcul ne peut etre execute.                         ',/,&
'@                                                            ',/,&
'@    Verifier les parametres.                                ',/,&
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/)
 8211 format(                                                     &
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/,&
'@ @@ ATTENTION : ARRET A LA VERIFICATION DES DONNEES         ',/,&
'@    =========                                               ',/,&
'@      SUR LES VARIABLES COMPOSANT LES MOYENNES TEMPORELLES  ',/,&
'@                                                            ',/,&
'@    IDFMOM(',I10   ,',',I10   ,') = ',I10                    ,/,&
'@      Les valeurs positives renvoient a des variables de    ',/,&
'@      calcul, or il n y en a que NVAR   = ', I10             ,/,&
'@    La valeur de IDFMOM est donc erronee.                   ',/,&
'@                                                            ',/,&
'@    Le calcul ne peut etre execute.                         ',/,&
'@                                                            ',/,&
'@    Verifier les parametres.                                ',/,&
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/)
 8212 format(                                                     &
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/,&
'@ @@ ATTENTION : ARRET A LA VERIFICATION DES DONNEES         ',/,&
'@    =========                                               ',/,&
'@      SUR LES VARIABLES COMPOSANT LES MOYENNES TEMPORELLES  ',/,&
'@                                                            ',/,&
'@    La valeur                                               ',/,&
'@      IDFMOM(',I10   ,',',I10   ,') = ',I10                  ,/,&
'@      n''est pas une propriete associee aux cellules        ',/,&
'@      (IPPROC(',I10   ,') = ',I10   ,')                     ',/,&
'@    La valeur de IDFMOM est donc erronee.                   ',/,&
'@                                                            ',/,&
'@    Le calcul ne peut etre execute.                         ',/,&
'@                                                            ',/,&
'@    Verifier les parametres.                                ',/,&
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/)
 8213 format(                                                     &
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/,&
'@ @@ ATTENTION : ARRET A LA VERIFICATION DES DONNEES         ',/,&
'@    =========                                               ',/,&
'@      SUR LES VARIABLES COMPOSANT LES MOYENNES TEMPORELLES  ',/,&
'@                                                            ',/,&
'@    Le tableau IDFMOM(JJ,IMOM) pour IMOM = ',I10             ,/,&
'@      doit etre renseigne continuement. Or ici,             ',/,&
'@      IDFMOM(',I10,',IMOM) est non nul (=',I10   ,')        ',/,&
'@      alors qu il existe II < JJ pour lequel                ',/,&
'@      IDFMOM(II,IMOM) est nul.                              ',/,&
'@    La valeur de IDFMOM est donc erronee.                   ',/,&
'@                                                            ',/,&
'@    Le calcul ne peut etre execute.                         ',/,&
'@                                                            ',/,&
'@    Verifier les parametres.                                ',/,&
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/)
 8900 format(                                                     &
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/,&
'@ @@ ATTENTION : ARRET A L''ENTREE DES DONNEES               ',/,&
'@    =========                                               ',/,&
'@     NOMBRE DE VARIABLES A SUIVRE TROP GRAND                ',/,&
'@                                                            ',/,&
'@  Le type de calcul defini                                  ',/,&
'@    correspond a un nombre de variables a suivre dans       ',/,&
'@    le listing et le post-processing egal a      ',I10       ,/,&
'@  Le nombre de variables a suivre maximal prevu             ',/,&
'@                      dans paramx.h est NVPPMX = ',I10       ,/,&
'@                                                            ',/,&
'@  Le calcul ne sera pas execute.                            ',/,&
'@                                                            ',/,&
'@  Verifier les parametres.                                  ',/,&
'@  Contacter l assistance.                                   ',/,&
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/)

#else

 8022 format(                                                     &
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/,&
'@ @@ WARNING   : STOP AT THE INITIAL DATA VERIFICATION       ',/,&
'@    =========                                               ',/,&
'@    ',A6,' MUST BE AN INTEGER EQUAL TO 0 OR 1               ',/,&
'@    HERE IT IS  ',I10                                        ,/,&
'@                                                            ',/,&
'@  The calculation cannot be executed                        ',/,&
'@                                                            ',/,&
'@  Verify   parameters.                                      ',/,&
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/)
 8101 format(                                                     &
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/,&
'@ @@ WARNING   : STOP AT THE INITIAL DATA VERIFICATION       ',/,&
'@    =========                                               ',/,&
'@    ',A6,' MUST BE AN INTEGER EQUAL TO 1 OR 2               ',/,&
'@    HERE IT IS  ',I10                                        ,/,&
'@                                                            ',/,&
'@  The calculation cannot be executed                        ',/,&
'@                                                            ',/,&
'@  Verifier parameters.                                      ',/,&
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/)
 8111 format(                                                     &
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/,&
'@ @@ WARNING   : STOP AT THE INITIAL DATA'                    ,/,&
'@    =========                                               ',/,&
'@    WITH A SECOND ORDER SCHEME IN TIME: ISCHTP = ', I10      ,/,&
'@    IT IS NECESSARY TO USE A CONSTANT AND UNIFORM TIME STEP ',/,&
'@    BUT IDTVAR = ',I10                                       ,/,&
'@                                                            ',/,&
'@  The calculation cannot be executed                        ',/,&
'@                                                            ',/,&
'@  Verifier parameters.                                      ',/,&
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/)
 8112 format(                                                     &
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/,&
'@ @@ WARNING   : STOP AT THE INITIAL DATA'                    ,/,&
'@    =========                                               ',/,&
'@    A 2ND ORDER SCHEME HAS BEEN IMPOSED    (ISCHTP = ',I10   ,/,&
'@    WITH K-EPSILON (ITURB = ',I10,' )'                       ,/,&
'@                                                            ',/,&
'@   The current version does not support the 2nd order with  ',/,&
'@   coupling of the source terms of k-epsilon.               ',/,&
'@                                                            ',/,&
'@  The calculation cannot be executed                        ',/,&
'@                                                            ',/,&
'@  Modify   parameters.                                      ',/,&
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/)
 8113 format(                                                     &
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/,&
'@ @@ WARNING   :      AT THE INITIAL DATA'                    ,/,&
'@    =========                                               ',/,&
'@    A 1st ORDER SCHEME HAS BEEN IMPOSSED   (ISCHTP = ',I10   ,/,&
'@    FOR LES (ITURB = ',I10,' )'                              ,/,&
'@                                                            ',/,&
'@  The calculation will   be executed                        ',/,&
'@                                                            ',/,&
'@  It is recommended to verify  parameters.                  ',/,&
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/)
 8114 format(                                                     &
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/,&
'@ @@ WARNING   : STOP AT THE INITIAL DATA'                    ,/,&
'@    =========                                               ',/,&
'@    A 2nd ORDER SCHEME HAS BEEN IMPOSED    (ISCHTP = ',I10   ,/,&
'@    FOR PHI_FBAR (ITURB = ',I10,' )'                         ,/,&
'@                                                            ',/,&
'@   The current version does not support the 2nd order with  ',/,&
'@   coupling of the source terms of k-epsilon.               ',/,&
'@                                                            ',/,&
'@  The calculation cannot be executed                        ',/,&
'@                                                            ',/,&
'@  Modify   parameters.                                      ',/,&
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/)
 8117 format(                                                     &
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/,&
'@ @@ WARNING   : STOP AT THE INITIAL DATA                    ',/,&
'@    =========                                               ',/,&
'@    A 2nd ORDER SCHEME HAS BEEN IMPOSED    (ISCHTP = ',I10   ,/,&
'@    FOR BL-V2/K  (ITURB = ',I10,' )'                        ,/,&
'@                                                            ',/,&
'@   The current version does not support the 2nd order with  ',/,&
'@   coupling of the source terms of k-epsilon.               ',/,&
'@                                                            ',/,&
'@  The calculation cannot be executed                        ',/,&
'@                                                            ',/,&
'@  Modify   parameters.                                      ',/,&
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/)
 8115 format(                                                     &
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/,&
'@ @@ WARNING   : STOP AT THE INITIAL DATA'                    ,/,&
'@    =========                                               ',/,&
'@    A 2nd ORDER SCHEME HAS BEEN IMPOSED    (ISCHTP = ',I10   ,/,&
'@    FOR K-OMEGA   (ITURB = ',I10,' )'                        ,/,&
'@                                                            ',/,&
'@   The current version does not support the 2nd order with  ',/,&
'@   coupling of the source terms of k-omega.                 ',/,&
'@                                                            ',/,&
'@  The calculation cannot be executed                        ',/,&
'@                                                            ',/,&
'@  Modify   parameters.                                      ',/,&
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/)
 8116 format(                                                     &
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/,&
'@ @@ WARNING   : STOP AT THE INITIAL DATA'                    ,/,&
'@    =========                                               ',/,&
'@    A 2nd ORDER SCHEME HAS BEEN IMPOSED    (ISCHTP = ',I10   ,/,&
'@    FOR SPALART   (ITURB = ',I10,' )'                        ,/,&
'@                                                            ',/,&
'@   The current version does not support the 2nd order with  ',/,&
'@   coupling of the source terms of Spalart-Allmaras.        ',/,&
'@                                                            ',/,&
'@  The calculation cannot be executed                        ',/,&
'@                                                            ',/,&
'@  Modify   parameters.                                      ',/,&
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/)
 8121 format(                                                     &
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/,&
'@ @@ WARNING   : STOP AT THE INITIAL DATA'                    ,/,&
'@    =========                                               ',/,&
'@    ',A6,' MUST BE AN INTEGER EQUAL TO 0, 1 OR 2            ',/,&
'@    HERE IT IS  ',I10                                        ,/,&
'@                                                            ',/,&
'@  The calculation cannot be executed                        ',/,&
'@                                                            ',/,&
'@  Verify   parameters.                                      ',/,&
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/)
 8131 format(                                                     &
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/,&
'@ @@ WARNING   : STOP AT THE INITIAL DATA'                    ,/,&
'@    =========                                               ',/,&
'@    ',A6,' MUST BE AN INTEGER EQUAL TO 0, 1 OR 2            ',/,&
'@    HERE IT IS  ',I10                                        ,/,&
'@                                                            ',/,&
'@  The calculation cannot be executed                        ',/,&
'@                                                            ',/,&
'@  Verify   parameters.                                      ',/,&
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/)
 8132 format(                                                     &
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/,&
'@ @@ WARNING   : STOP AT THE INITIAL DATA'                    ,/,&
'@    =========                                               ',/,&
'@                                                            ',/,&
'@  With the chosen turbulence model   , ITURB = ',I10         ,/,&
'@    the value of ISTO2T (extrapolation of the source terms  ',/,&
'@    for the turbulent variables) cannot be modified         ',/,&
'@    yet ISTO2T has been forced to ',I10                      ,/,&
'@                                                            ',/,&
'@  The calculation cannot be executed                        ',/,&
'@                                                            ',/,&
'@  Verify   parameters.                                      ',/,&
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/)
 8141 format(                                                     &
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/,&
'@ @@ WARNING   : STOP AT THE INITAL DATA FOR SCALARS    ',I10 ,/,&
'@    =========                                               ',/,&
'@    ',A6,' MUST BE AN INTEGER EQUAL TO 0, 1 OR 2            ',/,&
'@    HERE IT IS  ',I10                                        ,/,&
'@                                                            ',/,&
'@  The calculation cannot be executed                        ',/,&
'@                                                            ',/,&
'@  Verify   parameters.                                      ',/,&
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/)
 8200 format(                                                     &
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/,&
'@ @@ WARNING   : STOP AT THE VERIFICATION OF DATA            ',/,&
'@    =========                                               ',/,&
'@      ON THE LIST OF TEMPORAL AVERAGES                      ',/,&
'@                                                            ',/,&
'@    The value of IDFMOM(1,',I10   ,' is  ',I10               ,/,&
'@      this indicates that ',I10   ,' temporal averages have ',/,&
'@      been defined to find out the   IMOM = ',I10            ,/,&
'@      first locations of the array IDFMOM(.,IMOM).          ',/,&
'@    The follwing locations should be zero.                  ',/,&
'@                                                            ',/,&
'@    This however, is not the case  :                        ',/,&
'@                                                            ',/,&
'@        IMOM    IDFMOM(1,IMOM)                              ',/,&
'@  ----------------------------                              '  )
 8201 format(                                                     &
'@  ',I10   ,'        ',     I10                                 )
 8202 format(                                                     &
'@  ----------------------------                              ',/,&
'@                                                            ',/,&
'@  The calculation cannot be executed                        ',/,&
'@                                                            ',/,&
'@    Verify   parameters.                                    ',/,&
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/)
 8210 format(                                                     &
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/,&
'@ @@ WARNING   : STOP AT THE VERIFICATION OF DATA            ',/,&
'@    =========                                               ',/,&
'@    ON THE VARIABLES THAT CONSTITUTE THE TEMPORAL AVERAGES  ',/,&
'@                                                            ',/,&
'@    IDFMOM(',I10   ,',',I10   ,') = ',I10                    ,/,&
'@      The negative value reflect physical properties        ',/,&
'@      but there is none in          NPRMAX = ', I10          ,/,&
'@    The value of IDFMOM is wrongly set.                     ',/,&
'@                                                            ',/,&
'@  The calculation cannot be executed                        ',/,&
'@                                                            ',/,&
'@    Verify   parameters.                                    ',/,&
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/)
 8211 format(                                                     &
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/,&
'@ @@ WARNING   : STOP AT THE VERIFICATION OF DATA            ',/,&
'@    =========                                               ',/,&
'@    ON THE VARIABLES THAT CONSTITUTE THE TEMPORAL AVERAGES  ',/,&
'@                                                            ',/,&
'@    IDFMOM(',I10   ,',',I10   ,') = ',I10                    ,/,&
'@      The positive values reflect variables of the          ',/,&
'@      calculation, yet there none in NVAR   = ', I10         ,/,&
'@    The value of IDFMOM is wrongly set.                     ',/,&
'@                                                            ',/,&
'@  The calculation cannot be executed                        ',/,&
'@                                                            ',/,&
'@    Verify   parameters.                                    ',/,&
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/)
 8212 format(                                                     &
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/,&
'@ @@ WARNING   : STOP AT THE VERIFICATION OF DATA            ',/,&
'@    =========                                               ',/,&
'@    ON THE VARIABLES THAT CONSTITUTE THE TEMPORAL AVERAGES  ',/,&
'@                                                            ',/,&
'@    The value                                               ',/,&
'@      IDFMOM(',I10   ,',',I10   ,') = ',I10                  ,/,&
'@      is not a property associated with the cells           ',/,&
'@      (IPPROC(',I10   ,') = ',I10   ,')                     ',/,&
'@    The value of IDFMOM is wrongly set.                     ',/,&
'@                                                            ',/,&
'@  The calculation cannot be executed                        ',/,&
'@                                                            ',/,&
'@    Verify   parameters.                                    ',/,&
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/)
 8213 format(                                                     &
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/,&
'@ @@ WARNING   : STOP AT THE VERIFICATION OF DATA            ',/,&
'@    =========                                               ',/,&
'@    ON THE VARIABLES THAT CONSTITUTE THE TEMPORAL AVERAGES  ',/,&
'@                                                            ',/,&
'@    The array  IDFMOM(JJ,IMOM) for  IMOM = ',I10             ,/,&
'@      must be assigned continuously.     Yet here,          ',/,&
'@      IDFMOM(',I10,',IMOM) is not zero (=',I10   ,')        ',/,&
'@      while it exists    II < JJ for which                  ',/,&
'@      IDFMOM(II,IMOM) is zero.                              ',/,&
'@    The value of IDFMOM is wrongly set.                     ',/,&
'@                                                            ',/,&
'@  The calculation cannot be executed                        ',/,&
'@                                                            ',/,&
'@    Verify   parameters.                                    ',/,&
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/)
 8900 format(                                                     &
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/,&
'@ @@ WARNING   : STOP AT THE INITIAL DATA VERIFICATION       ',/,&
'@    =========                                               ',/,&
'@     NAME OF THE VARIABLE TO BE CONTINUED TOO LARGE         ',/,&
'@                                                            ',/,&
'@  The type of calcultion defined                            ',/,&
'@    corresponds to a number of variables to continue in     ',/,&
'@    the listing and  post-processing equal to    ',I10       ,/,&
'@  The maximum number of variables to continue in            ',/,&
'@                           paramx.h is  NVPPMX = ',I10       ,/,&
'@                                                            ',/,&
'@  The calculation cannot be executed                        ',/,&
'@                                                            ',/,&
'@  Verify   parameters.                                      ',/,&
'@  Contact help.                                             ',/,&
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/)

#endif

!===============================================================================
! 5. End
!===============================================================================

return
end subroutine varpos
