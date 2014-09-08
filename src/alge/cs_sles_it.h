#ifndef __CS_SLES_IT_H__
#define __CS_SLES_IT_H__

/*============================================================================
 * Sparse Linear Equation Solvers
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

/*----------------------------------------------------------------------------
 *  Local headers
 *----------------------------------------------------------------------------*/

#include "cs_base.h"
#include "cs_halo_perio.h"
#include "cs_matrix.h"

/*----------------------------------------------------------------------------*/

BEGIN_C_DECLS

/*============================================================================
 * Macro definitions
 *============================================================================*/

/*============================================================================
 * Type definitions
 *============================================================================*/

/*----------------------------------------------------------------------------
 * Solver types
 *----------------------------------------------------------------------------*/

typedef enum {

  CS_SLES_PCG,        /* Preconditionned conjugate gradient */
  CS_SLES_PCG_SR,     /* Preconditionned conjugate gradient, single reduction*/
  CS_SLES_JACOBI,     /* Jacobi */
  CS_SLES_BICGSTAB,   /* Bi-conjugate gradient stabilized */
  CS_SLES_BICGSTAB2,  /* Bi-conjugate gradient stabilized - 2*/
  CS_SLES_GMRES,      /* Generalized minimal residual */
  CS_SLES_N_IT_TYPES  /* Number of resolution algorithms */

} cs_sles_it_type_t;

/* Iterative linear solver context (opaque) */

typedef struct _cs_sles_it_t  cs_sles_it_t;

/*============================================================================
 *  Global variables
 *============================================================================*/

/* Short names for matrix types */

extern const char *cs_sles_it_type_name[];

/*=============================================================================
 * Public function prototypes
 *============================================================================*/

/*----------------------------------------------------------------------------
 * Define and associate an iterative sparse linear system solver
 * for a given field or equation name.
 *
 * If this system did not previously exist, it is added to the list of
 * "known" systems. Otherwise, its definition is replaced by the one
 * defined here.
 *
 * This is a utility function: if finer control is needed, see
 * cs_sles_define() and cs_sles_it_create().
 *
 * Note that this function returns a pointer directly to the iterative solver
 * management structure. This may be used to set further options,
 * for example using cs_sles_it_set_verbosity(). If needed, cs_sles_find()
 * may be used to obtain a pointer to the matching cs_sles_t container.
 *
 * parameters:
 *   f_id         <-- associated field id, or < 0
 *   name         <-- associated name if f_id < 0, or NULL
 *   solver_type  <-- type of solver (PCG, Jacobi, ...)
 *   poly_degree  <-- preconditioning polynomial degree
 *                    (0: diagonal; -1: non-preconditioned)
 *   n_max_iter   <-- maximum number of iterations
 *
 * returns:
 *   pointer to newly created iterative solver info object.
 *----------------------------------------------------------------------------*/

cs_sles_it_t *
cs_sles_it_define(int                 f_id,
                  const char         *name,
                  cs_sles_it_type_t   solver_type,
                  int                 poly_degree,
                  int                 n_max_iter);

/*----------------------------------------------------------------------------
 * Create iterative sparse linear system solver info and context.
 *
 * parameters:
 *   solver_type  <-- type of solver (PCG, Jacobi, ...)
 *   poly_degree  <-- preconditioning polynomial degree
 *                    (0: diagonal; -1: non-preconditioned)
 *   n_max_iter   <-- maximum number of iterations
 *   update_stats <-- automatic solver statistics indicator
 *
 * returns:
 *   pointer to newly created solver info object.
 *----------------------------------------------------------------------------*/

cs_sles_it_t *
cs_sles_it_create(cs_sles_it_type_t   solver_type,
                  int                 poly_degree,
                  int                 n_max_iter,
                  bool                update_stats);

/*----------------------------------------------------------------------------
 * Destroy iterative sparse linear system solver info and context.
 *
 * parameters:
 *   context  <-> pointer to iterative sparse linear solver info
 *                (actual type: cs_sles_it_t  **)
 *----------------------------------------------------------------------------*/

void
cs_sles_it_destroy(void  **context);

/*----------------------------------------------------------------------------
 * Create iterative sparse linear system solver info and context
 * based on existing info and context.
 *
 * parameters:
 *   context <-- pointer to reference info and context
 *               (actual type: cs_sles_it_t  *)
 *
 * returns:
 *   pointer to newly created solver info object
 *   (actual type: cs_sles_it_t  *)
 *----------------------------------------------------------------------------*/

void *
cs_sles_it_copy(const void  *context);

/*----------------------------------------------------------------------------
 * Set iterative sparse linear equation solver verbosity.
 *
 * parameters:
 *   context   <-> pointer to iterative sparse linear solver info
 *   verbosity <-- verbosity level
 *----------------------------------------------------------------------------*/

void
cs_sles_it_set_verbosity(cs_sles_it_t  *context,
                         int            verbosity);

/*----------------------------------------------------------------------------
 * Setup iterative sparse linear equation solver.
 *
 * parameters:
 *   context <-> pointer to iterative sparse linear solver info
 *               (actual type: cs_sles_it_t  *)
 *   name    <-- pointer to system name
 *   a       <-- associated matrix
 *----------------------------------------------------------------------------*/

void
cs_sles_it_setup(void               *context,
                 const char         *name,
                 const cs_matrix_t  *a);

/*----------------------------------------------------------------------------
 * Call iterative sparse linear equation solver.
 *
 * parameters:
 *   context       <-> pointer to iterative sparse linear solver info
 *                     (actual type: cs_sles_it_t  *)
 *   name          <-- pointer to system name
 *   a             <-- matrix
 *   rotation_mode <-- halo update option for rotational periodicity
 *   precision     <-- solver precision
 *   r_norm        <-- residue normalization
 *   n_iter        --> number of iterations
 *   residue       --> residue
 *   rhs           <-- right hand side
 *   vx            <-> system solution
 *   aux_size      <-- number of elements in aux_vectors (in bytes)
 *   aux_vectors   --- optional working area (internal allocation if NULL)
 *
 * returns:
 *   convergence state
 *----------------------------------------------------------------------------*/

cs_sles_convergence_state_t
cs_sles_it_solve(void                *context,
                 const char          *name,
                 const cs_matrix_t   *a,
                 cs_halo_rotation_t   rotation_mode,
                 double               precision,
                 double               r_norm,
                 int                 *n_iter,
                 double              *residue,
                 const cs_real_t     *rhs,
                 cs_real_t           *vx,
                 size_t               aux_size,
                 void                *aux_vectors);

/*----------------------------------------------------------------------------
 * Free iterative sparse linear equation solver setup context.
 *
 * This function frees resolution-related data, such as
 * buffers and preconditioning but does not free the whole context,
 * as info used for logging (especially performance data) is maintained.

 * parameters:
 *   context <-> pointer to iterative sparse linear solver info
 *               (actual type: cs_sles_it_t  *)
 *----------------------------------------------------------------------------*/

void
cs_sles_it_free(void  *context);

/*----------------------------------------------------------------------------
 * Log sparse linear equation solver info.
 *
 * parameters:
 *   context  <-> pointer to iterative sparse linear solver info
 *                (actual type: cs_sles_it_t  *)
 *   log_type <-- log type
 *----------------------------------------------------------------------------*/

void
cs_sles_it_log(const void  *context,
               cs_log_t     log_type);

/*----------------------------------------------------------------------------
 * Associate a similar info and context object with which some setup
 * data may be shared.
 *
 * This is especially useful for sharing preconditioning data between
 * similar solver contexts (for example ascending and descending multigrid
 * smoothers based on the same matrix).
 *
 * For preconditioning data to be effectively shared, cs_sles_it_setup()
 * (or cs_sles_it_solve()) must be called on "shareable" before being
 * called on "context" (without cs_sles_it_free() being called in between,
 * of course).
 *
 * It is the caller's responsibility to ensure the context is not used
 * for a cs_sles_it_setup() or cs_sles_it_solve() operation  after the
 * shareable object has been destroyed (normally by cs_sles_it_destroy()).
 *
 * parameters:
 *   context   <-> pointer to iterative sparse linear system solver info
 *   shareable <-- pointer to iterative solver info and context
 *                 whose context may be shared
 *----------------------------------------------------------------------------*/

void
cs_sles_it_set_shareable(cs_sles_it_t        *context,
                         const cs_sles_it_t  *shareable);

#if defined(HAVE_MPI)

/*----------------------------------------------------------------------------
 * Set MPI communicator for dot products.
 *
 * parameters:
 *   context <-> pointer to iterative sparse linear system solver info
 *   comm    <-- MPI communicator
 *----------------------------------------------------------------------------*/

void
cs_sles_it_set_mpi_reduce_comm(cs_sles_it_t  *context,
                               MPI_Comm       comm);

#endif /* defined(HAVE_MPI) */

/*----------------------------------------------------------------------------
 * Error handler for iterative sparse linear equation solver.
 *
 * In case of divergence or breakdown, this error handler outputs
 * postprocessing data to assist debugging, then aborts the run.
 * It does nothing in case the maximum iteration count is reached.
 *
 * parameters:
 *   context       <-> pointer to iterative sparse linear system solver info
 *                     (actual type: cs_sles_it_t  *)
 *   state         <-- convergence state
 *   name          <-- pointer to name of linear system
 *   a             <-- matrix
 *   rotation_mode <-- halo update option for rotational periodicity
 *   rhs           <-- right hand side
 *   vx            <-> system solution
 */
/*----------------------------------------------------------------------------*/

void
cs_sles_it_error_post_and_abort(void                         *context,
                                cs_sles_convergence_state_t   state,
                                const char                   *name,
                                const cs_matrix_t            *a,
                                cs_halo_rotation_t            rotation_mode,
                                const cs_real_t              *rhs,
                                cs_real_t                    *vx);

/*----------------------------------------------------------------------------*/

END_C_DECLS

#endif /* __CS_SLES_IT_H__ */
