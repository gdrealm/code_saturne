#ifndef __CS_BLAS_H__
#define __CS_BLAS_H__

/*============================================================================
 * Portability and fallback layer for BLAS functions
 *============================================================================*/

/*
  This file is part of Code_Saturne, a general-purpose CFD tool.

  Copyright (C) 1998-2014 EDF S.A.

  This program is free software; you can redistribute it and/or modify it under
  the terms of the GNU General Public License as published by the Free Software
  Foundation; either version 2 of the License, or (at your option) any later
  version.

  This program is distributed in the hope that it will be useful, but WITHOUT
  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
  FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
  details.

  You should have received a copy of the GNU General Public License along with
  this program; if not, write to the Free Software Foundation, Inc., 51 Franklin
  Street, Fifth Floor, Boston, MA 02110-1301, USA.
*/

/*----------------------------------------------------------------------------*/

#include "cs_defs.h"

/*----------------------------------------------------------------------------
 * External library headers
 *----------------------------------------------------------------------------*/

/*----------------------------------------------------------------------------
 *  Local headers
 *----------------------------------------------------------------------------*/

#include "cs_base.h"

/*----------------------------------------------------------------------------*/

BEGIN_C_DECLS

/*============================================================================
 * Macro definitions
 *============================================================================*/

/*============================================================================
 *  Public function prototypes for Fortran API
 *============================================================================*/

/* Return the dot product of 2 vectors: x.y */

double CS_PROCF(csdot, CSDOT)(const cs_int_t   *n,
                              const cs_real_t  *x,
                              const cs_real_t  *y);

/* Return the global residual of 2 extensiv vectors: x.y */

double CS_PROCF(csres, CSRES)(const cs_int_t   *n,
                              const cs_real_t  *vol,
                              const cs_real_t  *x,
                              const cs_real_t  *y);

/*============================================================================
 *  Public function prototypes or wrapper macros
 *============================================================================*/

/*----------------------------------------------------------------------------
 * Constant times a vector plus a vector: y <-- ax + y
 *
 * parameters:
 *   n <-- size of arrays x and y
 *   a <-- multiplier for x
 *   x <-- array of floating-point values
 *   y <-- array of floating-point values
 *----------------------------------------------------------------------------*/

void
cs_axpy(cs_lnum_t         n,
        double            a,
        const cs_real_t  *x,
        cs_real_t        *restrict y);

/*----------------------------------------------------------------------------
 * Return the dot product of 2 vectors: x.y
 *
 * For better precision, a superblock algorithm is used.
 *
 * parameters:
 *   n <-- size of arrays x and y
 *   x <-- array of floating-point values
 *   y<-- array of floating-point values
 *
 * returns:
 *   dot product
 *----------------------------------------------------------------------------*/

double
cs_dot(cs_lnum_t         n,
       const cs_real_t  *x,
       const cs_real_t  *y);

/*----------------------------------------------------------------------------
 * Return the global residual of 2 extensive vectors:
 *  1/sum(vol) . sum(X.Y/vol)
 *
 * For better precision, a superblock algorithm is used.
 *
 * parameters:
 *   n   <-- size of arrays x and y
 *   vol <-- array of floating-point values
 *   x   <-- array of floating-point values
 *   y   <-- array of floating-point values
 *
 * returns:
 *   global residual
 *----------------------------------------------------------------------------*/

double
cs_gres(cs_lnum_t         n,
        const cs_real_t  *vol,
        const cs_real_t  *x,
        const cs_real_t  *y);

/*----------------------------------------------------------------------------
 * Return dot products of a vector with itself: x.x
 *
 * For better precision, a superblock algorithm is used.
 *
 * parameters:
 *   n  <-- size of arrays x and y
 *   x  <-- array of floating-point values
 *
 * returns:
 *   dot product
 *----------------------------------------------------------------------------*/

double
cs_dot_xx(cs_lnum_t         n,
          const cs_real_t  *x);

/*----------------------------------------------------------------------------
 * Return the double dot product of 2 vectors: x.x, and x.y
 *
 * The products could be computed separately, but computing them
 * simultaneously adds more optimization opportunities and possibly better
 * cache behavior.
 *
 * For better precision, a superblock algorithm is used.
 *
 * parameters:
 *   n  <-- size of arrays x and y
 *   x  <-- array of floating-point values
 *   y  <-- array of floating-point values
 *   xx --> x.x dot product
 *   xy --> x.y dot product
 *----------------------------------------------------------------------------*/

void
cs_dot_xx_xy(cs_lnum_t                    n,
             const cs_real_t  *restrict   x,
             const cs_real_t  *restrict   y,
             double                      *xx,
             double                      *xy);

/*----------------------------------------------------------------------------
 * Return the double dot product of 3 vectors: x.y, and y.z
 *
 * The products could be computed separately, but computing them
 * simultaneously adds more optimization opportunities and possibly better
 * cache behavior.
 *
 * For better precision, a superblock algorithm is used.
 *
 * parameters:
 *   n  <-- size of arrays x and y
 *   x  <-- array of floating-point values
 *   y  <-- array of floating-point values
 *   z  <-- array of floating-point values
 *   xy --> x.y dot product
 *   yz --> x.z dot product
 *----------------------------------------------------------------------------*/

void
cs_dot_xy_yz(cs_lnum_t                    n,
             const cs_real_t  *restrict   x,
             const cs_real_t  *restrict   y,
             const cs_real_t  *restrict   z,
             double                      *xx,
             double                      *xy);

/*----------------------------------------------------------------------------
 * Return 3 dot products of 3 vectors: x.y, x.y, and y.z
 *
 * The products could be computed separately, but computing them
 * simultaneously adds more optimization opportunities and possibly better
 * cache behavior.
 *
 * For better precision, a superblock algorithm is used.
 *
 * parameters:
 *   n  <-- size of arrays x and y
 *   x  <-- array of floating-point values
 *   y  <-- array of floating-point values
 *   z  <-- array of floating-point values
 *   xx --> x.y dot product
 *   xy --> x.y dot product
 *   yz --> y.z dot product
 *----------------------------------------------------------------------------*/

void
cs_dot_xx_xy_yz(cs_lnum_t                    n,
                const cs_real_t  *restrict   x,
                const cs_real_t  *restrict   y,
                const cs_real_t  *restrict   z,
                double                      *xx,
                double                      *xy,
                double                      *yz);

/*----------------------------------------------------------------------------
 * Return 5 dot products of 3 vectors: x.x, y.y, x.y, x.z, and y.z
 *
 * The products could be computed separately, but computing them
 * simultaneously adds more optimization opportunities and possibly better
 * cache behavior.
 *
 * For better precision, a superblock algorithm is used.
 *
 * parameters:
 *   n  <-- size of arrays x and y
 *   x  <-- array of floating-point values
 *   y  <-- array of floating-point values
 *   z  <-- array of floating-point values
 *   xx --> x.y dot product
 *   yy --> y.y dot product
 *   xy --> x.y dot product
 *   xz --> x.z dot product
 *   yz --> y.z dot product
 *----------------------------------------------------------------------------*/

void
cs_dot_xx_yy_xy_xz_yz(cs_lnum_t                    n,
                      const cs_real_t  *restrict   x,
                      const cs_real_t  *restrict   y,
                      const cs_real_t  *restrict   z,
                      double                      *xx,
                      double                      *yy,
                      double                      *xy,
                      double                      *xz,
                      double                      *yz);

/*----------------------------------------------------------------------------
 * Return the global dot product of 2 vectors: x.y
 *
 * In parallel mode, the local results are summed on the default
 * global communicator.
 *
 * For better precision, a superblock algorithm is used.
 *
 * parameters:
 *   n <-- size of arrays x and y
 *   x <-- array of floating-point values
 *   y <-- array of floating-point values
 *
 * returns:
 *   dot product
 *----------------------------------------------------------------------------*/

double
cs_gdot(cs_lnum_t         n,
        const cs_real_t  *x,
        const cs_real_t  *y);

/*----------------------------------------------------------------------------*/

END_C_DECLS

#endif /* __CS_BLAS_H__ */
