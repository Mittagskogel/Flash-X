!> @copyright Copyright 2023 UChicago Argonne, LLC and contributors
!!
!! @licenseblock
!!   Licensed under the Apache License, Version 2.0 (the "License");
!!   you may not use this file except in compliance with the License.
!!
!!   Unless required by applicable law or agreed to in writing, software
!!   distributed under the License is distributed on an "AS IS" BASIS,
!!   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
!!   See the License for the specific language governing permissions and
!!   limitations under the License.
!! @endlicenseblock
!!
!! @file
!! @brief TimeAdvance implementation

!> @ingroup TimeAdvanceMain/StraongSplit
!!
!! @brief Implements TimeAdvance
!!
!! @details
!! This is the Strang Split implementation of time integration
!!
!! @stubref{TimeAdvance}

!!#define DEBUG_ADVANCE
#ifdef DEBUG_ALL
#define DEBUG_ADVANCE
#endif

#include "Simulation.h"
#include "constants.h"



!#define ENABLE_TRUNC_BURN
#define TRUNC_FROM 64
#define TRUNC_TO_E 0
#define TRUNC_TO_M 16

subroutine TimeAdvance(dt, dtold, time)

   use Hydro_interface, ONLY: Hydro, Hydro_gravPotIsAlreadyUpdated
   use Gravity_interface, ONLY: Gravity_potential, &
        Gravity_beginPotential, Gravity_finishPotential
   use RadTrans_interface, ONLY: RadTrans
   use Particles_interface, ONLY: Particles_advance, Particles_dump
   use Burn_interface, ONLY: Burn
   use Deleptonize_interface, ONLY: Deleptonize
   use Timers_interface, ONLY: Timers_start, Timers_stop
   use Stir_interface, ONLY : Stir
   use TimeAdvance_data, ONLY : ta_useAsyncGrav

   !RAPTOR
   use iso_c_binding

   implicit none

   real, intent(IN) :: dt, dtold, time


   !RAPTOR wrapper interfaces
   interface
      function f__raptor_truncate_op_func(tfunc, from_ieee, to_type, to_exponent, to_significand) &
           result (fty) bind (c)
        use iso_c_binding
        implicit none

        integer(c_int), intent(in), value :: from_ieee, to_type, to_exponent, to_significand
        type(c_funptr), intent(in), value :: tfunc
        type(c_funptr) :: fty
      end function f__raptor_truncate_op_func
      function f__raptor_truncate_op_func_ieee(tfunc, from_ieee, to_type, to_ieee) &
           result (fty) bind (c)
        use iso_c_binding
        implicit none

        integer(c_int), intent(in), value :: from_ieee, to_type, to_ieee
        type(c_funptr), intent(in), value :: tfunc
        type(c_funptr) :: fty
      end function f__raptor_truncate_op_func_ieee
   end interface

   procedure(Burn), pointer :: tr_Burn
   type(c_funptr) :: cptr

   cptr = c_funloc(Burn)
   cptr = f__raptor_truncate_op_func(cptr, TRUNC_FROM, 1, TRUNC_TO_E, TRUNC_TO_M)
   ! cptr = f__raptor_truncate_op_func(cptr, TRUNC_FROM, 0, 32)
   call c_f_procpointer(cptr, tr_computeFluxes)


   call Hydro(time, dt, dtOld)
#ifdef DEBUG_ADVANCE
   print *, 'returned from hydro '
#endif

   if (.NOT. Hydro_gravPotIsAlreadyUpdated()) then
      if (ta_useAsyncGrav) then
         call Timers_start("Gravity pot prep")
         call Gravity_beginPotential()
         call Timers_stop("Gravity pot prep")
      end if
   end if

#ifndef DRIVER_DIFFULAST
   ! 3. Diffusive processes:
   call RadTrans(dt)
#ifdef DEBUG_ADVANCE
   print *, 'returned from RadTrans'
#endif
#endif

   ! 4. Add source terms:
   call Timers_start("sourceTerms")
#ifdef ENABLE_TRUNC_BURN
   call tr_Burn(dt)
#else
   call Burn(dt)
#endif !ENABLE_TRUNC_BURN
   call Deleptonize(.false., dt, time)
   call Stir(dt)
   call Timers_stop("sourceTerms")
#ifdef DEBUG_ADVANCE
   print *, 'returned from sourceTerms'
#endif

#ifdef DRIVER_DIFFULAST
   ! 3. Diffusive processes: *** CHANGED ORDER !!! ***
   !    Radiation, viscosity, conduction, & magnetic registivity
   call RadTrans(dt)
#endif

   ! #. Advance Particles
   call Timers_start("Particles_advance")
   call Particles_advance(dtOld, dt)
   call Timers_stop("Particles_advance")
#ifdef DEBUG_ADVANCE
   print *, 'return from Particles_advance '  ! DEBUG
#endif

   !Allows evolution of gravitational potential for Spark Hydro
   ! #. Calculate gravitational potentials - 2nd Operation
   if (.NOT. Hydro_gravPotIsAlreadyUpdated()) then
      call Timers_start("Gravity potential")
      if (ta_useAsyncGrav) then
         call Gravity_finishPotential()
      else
         call Gravity_potential()
      end if
      call Timers_stop("Gravity potential")
#ifdef DEBUG_ADVANCE
      print *, 'return from Gravity_potential '  ! DEBUG
#endif
   end if

end subroutine TimeAdvance
