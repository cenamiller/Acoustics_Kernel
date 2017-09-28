!KGEN-generated Fortran source file 
  
!Generated at : 2017-07-10 20:57:30 
!KGEN version : 0.7.1 
  
! Copyright (c) 2013,  Los Alamos National Security, LLC (LANS)
! and the University Corporation for Atmospheric Research (UCAR).
!
! Unless noted otherwise source code is licensed under the BSD license.
! Additional copyright and license information can be found in the LICENSE file
! distributed with this code, or at http://mpas-dev.github.com/license.html
!

module atm_time_integration

    USE mpas_kind_types 
   ! Added only clause to keep xlf90 from getting confused from the overloaded abs intrinsic in mpas_timekeeping


    USE mpas_atm_iau 

    USE kgen_utils_mod, ONLY: kgen_dp, kgen_array_sumcheck 
    USE tprof_mod, ONLY: tstart, tstop, tnull, tprnt 
    USE kgen_utils_mod, ONLY: check_t, kgen_init_check, CHECK_IDENTICAL, CHECK_IN_TOL, CHECK_OUT_TOL 

   ! Used to store physics tendencies for dynamics variables
   
   ! Used in compute_dyn_tend
!   real (kind=RKIND), allocatable, dimension(:,:) :: delsq_circulation    ! no longer used -> removed 

   ! Used in atm_advance_scalars

   ! Used in atm_advance_scalars_mono

   ! Used in compute_solve_diagnostics

      
    PUBLIC atm_advance_acoustic_step 
   contains


   SUBROUTINE atm_advance_acoustic_step(kgen_unit, kgen_elapsed_time, kgen_isverified, small_step, ncells, dts, cellstart, &
   &cellend, vertexstart, vertexend, edgestart, edgeend, cellsolvestart, cellsolveend, vertexsolvestart, vertexsolveend, &
   &edgesolvestart, edgesolveend) 

      !  This subroutine performs the entire acoustic step update, following Klemp et al MWR 2007,
      !  using forward-backward vertically implicit integration.  
      !  The gravity-waves are included in the acoustic-step integration.
      !  The input state variables that are updated are ru_p, rw_p (note that this is (rho*omega)_p here),
      !  rtheta_p, and rho_pp.  The time averaged mass flux is accumulated in ruAvg and wwAvg

       USE kgen_utils_mod, ONLY: kgen_dp, kgen_array_sumcheck 
       USE kgen_utils_mod, ONLY: check_t, kgen_init_check, CHECK_IDENTICAL, CHECK_IN_TOL, CHECK_OUT_TOL 
       USE kgen_utils_mod, ONLY: kgen_perturb_real 
       IMPLICIT NONE 

       INTEGER, INTENT(INOUT) :: small_step 
       INTEGER, INTENT(INOUT) :: ncells 
       REAL(KIND=rkind), INTENT(INOUT) :: dts 
       INTEGER, INTENT(INOUT) :: cellstart, cellend, vertexstart, vertexend, edgestart, edgeend 
       INTEGER, INTENT(INOUT) :: cellsolvestart, cellsolveend, vertexsolvestart, vertexsolveend, edgesolvestart, edgesolveend 


       REAL(KIND=rkind), dimension(:,:), pointer :: rho_zz, theta_m, ru_p, rw_p, rtheta_pp, rtheta_pp_old, zz, exner, cqu, ruavg, &
       &wwavg, rho_pp, cofwt, coftz, zxu, a_tri, alpha_tri, gamma_tri, dss, tend_ru, tend_rho, tend_rt, tend_rw, zgrid, cofwr, &
       &cofwz, w 

! redefine ru_p to be perturbation from time t, change 3a  ! temporary
       REAL(KIND=rkind), dimension(:,:), pointer :: ru 
       REAL(KIND=rkind), dimension(:,:), pointer :: ru_save 
! redefine rw_p to be perturbation from time t, change 3a  ! temporary
       REAL(KIND=rkind), dimension(:,:), pointer :: rw 
       REAL(KIND=rkind), dimension(:,:), pointer :: rw_save 

       REAL(KIND=rkind), dimension(:), pointer :: fzm, fzp, rdzw, dcedge, invdcedge, invareacell, cofrz, dvedge 

       INTEGER, dimension(:), pointer :: nedgesoncell 
       INTEGER, dimension(:,:), pointer :: cellsonedge, edgesoncell 
       REAL(KIND=rkind), dimension(:,:), pointer :: edgesoncell_sign 

       REAL(KIND=rkind), pointer :: epssm 

       REAL(KIND=rkind), pointer :: cf1, cf2, cf3 

       INTEGER, pointer :: nedges, ncellssolve 

       INTEGER, INTENT(IN) :: kgen_unit 
       REAL(KIND=kgen_dp), INTENT(OUT) :: kgen_elapsed_time 
       LOGICAL, INTENT(OUT) :: kgen_isverified 
       LOGICAL :: kgen_istrue 
       REAL(KIND=8) :: kgen_array_sum 
         
       REAL(KIND=rkind), pointer, dimension(:,:) :: kgenref_rho_zz 
       REAL(KIND=rkind), pointer, dimension(:,:) :: kgenref_theta_m 
       REAL(KIND=rkind), pointer, dimension(:,:) :: kgenref_ru_p 
       REAL(KIND=rkind), pointer, dimension(:,:) :: kgenref_rw_p 
       REAL(KIND=rkind), pointer, dimension(:,:) :: kgenref_rtheta_pp 
       REAL(KIND=rkind), pointer, dimension(:,:) :: kgenref_rtheta_pp_old 
       REAL(KIND=rkind), pointer, dimension(:,:) :: kgenref_zz 
       REAL(KIND=rkind), pointer, dimension(:,:) :: kgenref_exner 
       REAL(KIND=rkind), pointer, dimension(:,:) :: kgenref_cqu 
       REAL(KIND=rkind), pointer, dimension(:,:) :: kgenref_ruavg 
       REAL(KIND=rkind), pointer, dimension(:,:) :: kgenref_wwavg 
       REAL(KIND=rkind), pointer, dimension(:,:) :: kgenref_rho_pp 
       REAL(KIND=rkind), pointer, dimension(:,:) :: kgenref_cofwt 
       REAL(KIND=rkind), pointer, dimension(:,:) :: kgenref_coftz 
       REAL(KIND=rkind), pointer, dimension(:,:) :: kgenref_zxu 
       REAL(KIND=rkind), pointer, dimension(:,:) :: kgenref_a_tri 
       REAL(KIND=rkind), pointer, dimension(:,:) :: kgenref_alpha_tri 
       REAL(KIND=rkind), pointer, dimension(:,:) :: kgenref_gamma_tri 
       REAL(KIND=rkind), pointer, dimension(:,:) :: kgenref_dss 
       REAL(KIND=rkind), pointer, dimension(:,:) :: kgenref_tend_ru 
       REAL(KIND=rkind), pointer, dimension(:,:) :: kgenref_tend_rho 
       REAL(KIND=rkind), pointer, dimension(:,:) :: kgenref_tend_rt 
       REAL(KIND=rkind), pointer, dimension(:,:) :: kgenref_tend_rw 
       REAL(KIND=rkind), pointer, dimension(:,:) :: kgenref_zgrid 
       REAL(KIND=rkind), pointer, dimension(:,:) :: kgenref_cofwr 
       REAL(KIND=rkind), pointer, dimension(:,:) :: kgenref_cofwz 
       REAL(KIND=rkind), pointer, dimension(:,:) :: kgenref_w 
       REAL(KIND=rkind), pointer, dimension(:,:) :: kgenref_ru 
       REAL(KIND=rkind), pointer, dimension(:,:) :: kgenref_ru_save 
       REAL(KIND=rkind), pointer, dimension(:,:) :: kgenref_rw 
       REAL(KIND=rkind), pointer, dimension(:,:) :: kgenref_rw_save 
       REAL(KIND=rkind), pointer, dimension(:) :: kgenref_fzm 
       REAL(KIND=rkind), pointer, dimension(:) :: kgenref_fzp 
       REAL(KIND=rkind), pointer, dimension(:) :: kgenref_rdzw 
       REAL(KIND=rkind), pointer, dimension(:) :: kgenref_dcedge 
       REAL(KIND=rkind), pointer, dimension(:) :: kgenref_invdcedge 
       REAL(KIND=rkind), pointer, dimension(:) :: kgenref_invareacell 
       REAL(KIND=rkind), pointer, dimension(:) :: kgenref_cofrz 
       REAL(KIND=rkind), pointer, dimension(:) :: kgenref_dvedge 
       INTEGER, pointer, dimension(:) :: kgenref_nedgesoncell 
       INTEGER, pointer, dimension(:,:) :: kgenref_cellsonedge 
       INTEGER, pointer, dimension(:,:) :: kgenref_edgesoncell 
       REAL(KIND=rkind), pointer, dimension(:,:) :: kgenref_edgesoncell_sign 
       TYPE(check_t) :: check_status 
       INTEGER*8 :: kgen_intvar, kgen_start_clock, kgen_stop_clock, kgen_rate_clock 
       INTEGER, PARAMETER :: kgen_maxiter = 1 

!      call mpas_pool_get_array(state, 'theta_m', theta_m, 2)
!  change needed for rw_p, change 6 (see rayleigh damping)
!      call mpas_pool_get_array(state, 'w', w, 1)


! redefine ru_p to be perturbation from time t, change 3b ! temporary
! redefine rw_p to be perturbation from time t, change 3b ! temporary

      ! epssm is the offcentering coefficient for the vertically implicit integration.

!$KGEN begin_callsite atm_advance_acoustic_step_work
         
       !local input variables 
       CALL kr_atm_advance_acoustic_step_real__rkind_dim2_ptr(rho_zz, kgen_unit) 
       CALL kr_atm_advance_acoustic_step_real__rkind_dim2_ptr(theta_m, kgen_unit) 
       CALL kr_atm_advance_acoustic_step_real__rkind_dim2_ptr(ru_p, kgen_unit) 
       CALL kr_atm_advance_acoustic_step_real__rkind_dim2_ptr(rw_p, kgen_unit) 
       CALL kr_atm_advance_acoustic_step_real__rkind_dim2_ptr(rtheta_pp, kgen_unit) 
       CALL kr_atm_advance_acoustic_step_real__rkind_dim2_ptr(rtheta_pp_old, kgen_unit) 
       CALL kr_atm_advance_acoustic_step_real__rkind_dim2_ptr(zz, kgen_unit) 
       CALL kr_atm_advance_acoustic_step_real__rkind_dim2_ptr(exner, kgen_unit) 
       CALL kr_atm_advance_acoustic_step_real__rkind_dim2_ptr(cqu, kgen_unit) 
       CALL kr_atm_advance_acoustic_step_real__rkind_dim2_ptr(ruavg, kgen_unit) 
       CALL kr_atm_advance_acoustic_step_real__rkind_dim2_ptr(wwavg, kgen_unit) 
       CALL kr_atm_advance_acoustic_step_real__rkind_dim2_ptr(rho_pp, kgen_unit) 
       CALL kr_atm_advance_acoustic_step_real__rkind_dim2_ptr(cofwt, kgen_unit) 
       CALL kr_atm_advance_acoustic_step_real__rkind_dim2_ptr(coftz, kgen_unit) 
       CALL kr_atm_advance_acoustic_step_real__rkind_dim2_ptr(zxu, kgen_unit) 
       CALL kr_atm_advance_acoustic_step_real__rkind_dim2_ptr(a_tri, kgen_unit) 
       CALL kr_atm_advance_acoustic_step_real__rkind_dim2_ptr(alpha_tri, kgen_unit) 
       CALL kr_atm_advance_acoustic_step_real__rkind_dim2_ptr(gamma_tri, kgen_unit) 
       CALL kr_atm_advance_acoustic_step_real__rkind_dim2_ptr(dss, kgen_unit) 
       CALL kr_atm_advance_acoustic_step_real__rkind_dim2_ptr(tend_ru, kgen_unit) 
       CALL kr_atm_advance_acoustic_step_real__rkind_dim2_ptr(tend_rho, kgen_unit) 
       CALL kr_atm_advance_acoustic_step_real__rkind_dim2_ptr(tend_rt, kgen_unit) 
       CALL kr_atm_advance_acoustic_step_real__rkind_dim2_ptr(tend_rw, kgen_unit) 
       CALL kr_atm_advance_acoustic_step_real__rkind_dim2_ptr(zgrid, kgen_unit) 
       CALL kr_atm_advance_acoustic_step_real__rkind_dim2_ptr(cofwr, kgen_unit) 
       CALL kr_atm_advance_acoustic_step_real__rkind_dim2_ptr(cofwz, kgen_unit) 
       CALL kr_atm_advance_acoustic_step_real__rkind_dim2_ptr(w, kgen_unit) 
       CALL kr_atm_advance_acoustic_step_real__rkind_dim2_ptr(ru, kgen_unit) 
       CALL kr_atm_advance_acoustic_step_real__rkind_dim2_ptr(ru_save, kgen_unit) 
       CALL kr_atm_advance_acoustic_step_real__rkind_dim2_ptr(rw, kgen_unit) 
       CALL kr_atm_advance_acoustic_step_real__rkind_dim2_ptr(rw_save, kgen_unit) 
       CALL kr_atm_advance_acoustic_step_real__rkind_dim1_ptr(fzm, kgen_unit) 
       CALL kr_atm_advance_acoustic_step_real__rkind_dim1_ptr(fzp, kgen_unit) 
       CALL kr_atm_advance_acoustic_step_real__rkind_dim1_ptr(rdzw, kgen_unit) 
       CALL kr_atm_advance_acoustic_step_real__rkind_dim1_ptr(dcedge, kgen_unit) 
       CALL kr_atm_advance_acoustic_step_real__rkind_dim1_ptr(invdcedge, kgen_unit) 
       CALL kr_atm_advance_acoustic_step_real__rkind_dim1_ptr(invareacell, kgen_unit) 
       CALL kr_atm_advance_acoustic_step_real__rkind_dim1_ptr(cofrz, kgen_unit) 
       CALL kr_atm_advance_acoustic_step_real__rkind_dim1_ptr(dvedge, kgen_unit) 
       CALL kr_atm_advance_acoustic_step_integer___dim1_ptr(nedgesoncell, kgen_unit) 
       CALL kr_atm_advance_acoustic_step_integer___dim2_ptr(cellsonedge, kgen_unit) 
       CALL kr_atm_advance_acoustic_step_integer___dim2_ptr(edgesoncell, kgen_unit) 
       CALL kr_atm_advance_acoustic_step_real__rkind_dim2_ptr(edgesoncell_sign, kgen_unit) 
       CALL kr_atm_advance_acoustic_step_real__rkind_ptr(epssm, kgen_unit) 
       CALL kr_atm_advance_acoustic_step_real__rkind_ptr(cf1, kgen_unit) 
       CALL kr_atm_advance_acoustic_step_real__rkind_ptr(cf2, kgen_unit) 
       CALL kr_atm_advance_acoustic_step_real__rkind_ptr(cf3, kgen_unit) 
       CALL kr_atm_advance_acoustic_step_integer___ptr(nedges, kgen_unit) 
       CALL kr_atm_advance_acoustic_step_integer___ptr(ncellssolve, kgen_unit) 
         
       !extern output variables 
         
       !local output variables 
       CALL kr_atm_advance_acoustic_step_real__rkind_dim2_ptr(kgenref_rho_zz, kgen_unit) 
       CALL kr_atm_advance_acoustic_step_real__rkind_dim2_ptr(kgenref_theta_m, kgen_unit) 
       CALL kr_atm_advance_acoustic_step_real__rkind_dim2_ptr(kgenref_ru_p, kgen_unit) 
       CALL kr_atm_advance_acoustic_step_real__rkind_dim2_ptr(kgenref_rw_p, kgen_unit) 
       CALL kr_atm_advance_acoustic_step_real__rkind_dim2_ptr(kgenref_rtheta_pp, kgen_unit) 
       CALL kr_atm_advance_acoustic_step_real__rkind_dim2_ptr(kgenref_rtheta_pp_old, kgen_unit) 
       CALL kr_atm_advance_acoustic_step_real__rkind_dim2_ptr(kgenref_zz, kgen_unit) 
       CALL kr_atm_advance_acoustic_step_real__rkind_dim2_ptr(kgenref_exner, kgen_unit) 
       CALL kr_atm_advance_acoustic_step_real__rkind_dim2_ptr(kgenref_cqu, kgen_unit) 
       CALL kr_atm_advance_acoustic_step_real__rkind_dim2_ptr(kgenref_ruavg, kgen_unit) 
       CALL kr_atm_advance_acoustic_step_real__rkind_dim2_ptr(kgenref_wwavg, kgen_unit) 
       CALL kr_atm_advance_acoustic_step_real__rkind_dim2_ptr(kgenref_rho_pp, kgen_unit) 
       CALL kr_atm_advance_acoustic_step_real__rkind_dim2_ptr(kgenref_cofwt, kgen_unit) 
       CALL kr_atm_advance_acoustic_step_real__rkind_dim2_ptr(kgenref_coftz, kgen_unit) 
       CALL kr_atm_advance_acoustic_step_real__rkind_dim2_ptr(kgenref_zxu, kgen_unit) 
       CALL kr_atm_advance_acoustic_step_real__rkind_dim2_ptr(kgenref_a_tri, kgen_unit) 
       CALL kr_atm_advance_acoustic_step_real__rkind_dim2_ptr(kgenref_alpha_tri, kgen_unit) 
       CALL kr_atm_advance_acoustic_step_real__rkind_dim2_ptr(kgenref_gamma_tri, kgen_unit) 
       CALL kr_atm_advance_acoustic_step_real__rkind_dim2_ptr(kgenref_dss, kgen_unit) 
       CALL kr_atm_advance_acoustic_step_real__rkind_dim2_ptr(kgenref_tend_ru, kgen_unit) 
       CALL kr_atm_advance_acoustic_step_real__rkind_dim2_ptr(kgenref_tend_rho, kgen_unit) 
       CALL kr_atm_advance_acoustic_step_real__rkind_dim2_ptr(kgenref_tend_rt, kgen_unit) 
       CALL kr_atm_advance_acoustic_step_real__rkind_dim2_ptr(kgenref_tend_rw, kgen_unit) 
       CALL kr_atm_advance_acoustic_step_real__rkind_dim2_ptr(kgenref_zgrid, kgen_unit) 
       CALL kr_atm_advance_acoustic_step_real__rkind_dim2_ptr(kgenref_cofwr, kgen_unit) 
       CALL kr_atm_advance_acoustic_step_real__rkind_dim2_ptr(kgenref_cofwz, kgen_unit) 
       CALL kr_atm_advance_acoustic_step_real__rkind_dim2_ptr(kgenref_w, kgen_unit) 
       CALL kr_atm_advance_acoustic_step_real__rkind_dim2_ptr(kgenref_ru, kgen_unit) 
       CALL kr_atm_advance_acoustic_step_real__rkind_dim2_ptr(kgenref_ru_save, kgen_unit) 
       CALL kr_atm_advance_acoustic_step_real__rkind_dim2_ptr(kgenref_rw, kgen_unit) 
       CALL kr_atm_advance_acoustic_step_real__rkind_dim2_ptr(kgenref_rw_save, kgen_unit) 
       CALL kr_atm_advance_acoustic_step_real__rkind_dim1_ptr(kgenref_fzm, kgen_unit) 
       CALL kr_atm_advance_acoustic_step_real__rkind_dim1_ptr(kgenref_fzp, kgen_unit) 
       CALL kr_atm_advance_acoustic_step_real__rkind_dim1_ptr(kgenref_rdzw, kgen_unit) 
       CALL kr_atm_advance_acoustic_step_real__rkind_dim1_ptr(kgenref_dcedge, kgen_unit) 
       CALL kr_atm_advance_acoustic_step_real__rkind_dim1_ptr(kgenref_invdcedge, kgen_unit) 
       CALL kr_atm_advance_acoustic_step_real__rkind_dim1_ptr(kgenref_invareacell, kgen_unit) 
       CALL kr_atm_advance_acoustic_step_real__rkind_dim1_ptr(kgenref_cofrz, kgen_unit) 
       CALL kr_atm_advance_acoustic_step_real__rkind_dim1_ptr(kgenref_dvedge, kgen_unit) 
       CALL kr_atm_advance_acoustic_step_integer___dim1_ptr(kgenref_nedgesoncell, kgen_unit) 
       CALL kr_atm_advance_acoustic_step_integer___dim2_ptr(kgenref_cellsonedge, kgen_unit) 
       CALL kr_atm_advance_acoustic_step_integer___dim2_ptr(kgenref_edgesoncell, kgen_unit) 
       CALL kr_atm_advance_acoustic_step_real__rkind_dim2_ptr(kgenref_edgesoncell_sign, kgen_unit) 
         
       !Uncomment following call statement to turn on perturbation experiment. 
       !Adjust perturbation value and/or kind parameter if required. 
       !CALL kgen_perturb_real( your_variable, 1.0E-15_8 ) 
         
         
       !call to kgen kernel 
      call atm_advance_acoustic_step_work(nCells, nEdges, nCellsSolve, cellStart, cellEnd, vertexStart, vertexEnd, edgeStart, edgeEnd, &
                                   cellSolveStart, cellSolveEnd, vertexSolveStart, vertexSolveEnd, edgeSolveStart, edgeSolveEnd, &
                                   rho_zz, theta_m, ru_p, rw_p, rtheta_pp, rtheta_pp_old, zz, exner, cqu, ruAvg, wwAvg, &
                                   rho_pp, cofwt, coftz, zxu, a_tri, alpha_tri, gamma_tri, dss, tend_ru, tend_rho, tend_rt, &
                                   tend_rw, zgrid, cofwr, cofwz, w, ru, ru_save, rw, rw_save, fzm, fzp, rdzw, dcEdge, invDcEdge, &
                                   invAreaCell, cofrz, dvEdge, nEdgesOnCell, cellsOnEdge, edgesOnCell, edgesOnCell_sign, &
                                   dts, small_step, epssm, cf1, cf2, cf3 &
                                   )
!$KGEN end_callsite atm_advance_acoustic_step_work
        
      !verify init 
      CALL kgen_init_check(check_status, tolerance=1.D-14, verboseLevel=1) 
        
      !extern verify variables 
        
      !local verify variables 
      CALL kv_atm_advance_acoustic_step_real__rkind_dim2_ptr("rw_p", check_status, rw_p, kgenref_rw_p) 
      CALL kv_atm_advance_acoustic_step_real__rkind_dim2_ptr("ru_p", check_status, ru_p, kgenref_ru_p) 
      CALL kv_atm_advance_acoustic_step_real__rkind_dim2_ptr("rho_pp", check_status, rho_pp, kgenref_rho_pp) 
      CALL kv_atm_advance_acoustic_step_real__rkind_dim2_ptr("coftz", check_status, coftz, kgenref_coftz) 
      CALL kv_atm_advance_acoustic_step_real__rkind_dim2_ptr("tend_rw", check_status, tend_rw, kgenref_tend_rw) 
      CALL kv_atm_advance_acoustic_step_real__rkind_dim2_ptr("tend_ru", check_status, tend_ru, kgenref_tend_ru) 
      CALL kv_atm_advance_acoustic_step_real__rkind_dim2_ptr("tend_rt", check_status, tend_rt, kgenref_tend_rt) 
      CALL kv_atm_advance_acoustic_step_real__rkind_dim2_ptr("zz", check_status, zz, kgenref_zz) 
      CALL kv_atm_advance_acoustic_step_real__rkind_dim2_ptr("zgrid", check_status, zgrid, kgenref_zgrid) 
      CALL kv_atm_advance_acoustic_step_real__rkind_dim2_ptr("dss", check_status, dss, kgenref_dss) 
      CALL kv_atm_advance_acoustic_step_real__rkind_dim2_ptr("cofwt", check_status, cofwt, kgenref_cofwt) 
      CALL kv_atm_advance_acoustic_step_real__rkind_dim2_ptr("zxu", check_status, zxu, kgenref_zxu) 
      CALL kv_atm_advance_acoustic_step_real__rkind_dim2_ptr("cofwr", check_status, cofwr, kgenref_cofwr) 
      CALL kv_atm_advance_acoustic_step_real__rkind_dim2_ptr("gamma_tri", check_status, gamma_tri, kgenref_gamma_tri) 
      CALL kv_atm_advance_acoustic_step_real__rkind_dim2_ptr("cqu", check_status, cqu, kgenref_cqu) 
      CALL kv_atm_advance_acoustic_step_real__rkind_dim2_ptr("rtheta_pp", check_status, rtheta_pp, kgenref_rtheta_pp) 
      CALL kv_atm_advance_acoustic_step_real__rkind_dim2_ptr("alpha_tri", check_status, alpha_tri, kgenref_alpha_tri) 
      CALL kv_atm_advance_acoustic_step_real__rkind_dim2_ptr("tend_rho", check_status, tend_rho, kgenref_tend_rho) 
      CALL kv_atm_advance_acoustic_step_real__rkind_dim2_ptr("exner", check_status, exner, kgenref_exner) 
      CALL kv_atm_advance_acoustic_step_real__rkind_dim2_ptr("rtheta_pp_old", check_status, rtheta_pp_old, kgenref_rtheta_pp_old) 
      CALL kv_atm_advance_acoustic_step_real__rkind_dim2_ptr("ruavg", check_status, ruavg, kgenref_ruavg) 
      CALL kv_atm_advance_acoustic_step_real__rkind_dim2_ptr("theta_m", check_status, theta_m, kgenref_theta_m) 
      CALL kv_atm_advance_acoustic_step_real__rkind_dim2_ptr("rho_zz", check_status, rho_zz, kgenref_rho_zz) 
      CALL kv_atm_advance_acoustic_step_real__rkind_dim2_ptr("cofwz", check_status, cofwz, kgenref_cofwz) 
      CALL kv_atm_advance_acoustic_step_real__rkind_dim2_ptr("w", check_status, w, kgenref_w) 
      CALL kv_atm_advance_acoustic_step_real__rkind_dim2_ptr("a_tri", check_status, a_tri, kgenref_a_tri) 
      CALL kv_atm_advance_acoustic_step_real__rkind_dim2_ptr("wwavg", check_status, wwavg, kgenref_wwavg) 
      CALL kv_atm_advance_acoustic_step_real__rkind_dim2_ptr("ru", check_status, ru, kgenref_ru) 
      CALL kv_atm_advance_acoustic_step_real__rkind_dim2_ptr("ru_save", check_status, ru_save, kgenref_ru_save) 
      CALL kv_atm_advance_acoustic_step_real__rkind_dim2_ptr("rw", check_status, rw, kgenref_rw) 
      CALL kv_atm_advance_acoustic_step_real__rkind_dim2_ptr("rw_save", check_status, rw_save, kgenref_rw_save) 
      CALL kv_atm_advance_acoustic_step_real__rkind_dim1_ptr("invareacell", check_status, invareacell, kgenref_invareacell) 
      CALL kv_atm_advance_acoustic_step_real__rkind_dim1_ptr("invdcedge", check_status, invdcedge, kgenref_invdcedge) 
      CALL kv_atm_advance_acoustic_step_real__rkind_dim1_ptr("fzp", check_status, fzp, kgenref_fzp) 
      CALL kv_atm_advance_acoustic_step_real__rkind_dim1_ptr("cofrz", check_status, cofrz, kgenref_cofrz) 
      CALL kv_atm_advance_acoustic_step_real__rkind_dim1_ptr("fzm", check_status, fzm, kgenref_fzm) 
      CALL kv_atm_advance_acoustic_step_real__rkind_dim1_ptr("rdzw", check_status, rdzw, kgenref_rdzw) 
      CALL kv_atm_advance_acoustic_step_real__rkind_dim1_ptr("dcedge", check_status, dcedge, kgenref_dcedge) 
      CALL kv_atm_advance_acoustic_step_real__rkind_dim1_ptr("dvedge", check_status, dvedge, kgenref_dvedge) 
      CALL kv_atm_advance_acoustic_step_integer___dim1_ptr("nedgesoncell", check_status, nedgesoncell, kgenref_nedgesoncell) 
      CALL kv_atm_advance_acoustic_step_integer___dim2_ptr("cellsonedge", check_status, cellsonedge, kgenref_cellsonedge) 
      CALL kv_atm_advance_acoustic_step_integer___dim2_ptr("edgesoncell", check_status, edgesoncell, kgenref_edgesoncell) 
      CALL kv_atm_advance_acoustic_step_real__rkind_dim2_ptr("edgesoncell_sign", check_status, edgesoncell_sign, &
      &kgenref_edgesoncell_sign) 
      WRITE (*, *) "" 
      IF (check_status%verboseLevel > 0) THEN 
          WRITE (*, *) "Number of output-type variables: ", check_status%numTotal 
          WRITE (*, *) "Number of identical variables: ", check_status%numIdentical 
          WRITE (*, *) "Number of non-identical variables within tolerance: ", check_status%numInTol 
          WRITE (*, *) "Number of non-identical variables out of tolerance: ", check_status%numOutTol 
          WRITE (*, *) "Tolerance: ", check_status%tolerance 
      END IF   
      WRITE (*, *) "" 
      IF (check_status%numOutTol > 0) THEN 
          WRITE (*, *) "Verification FAILED" 
          check_status%Passed = .FALSE. 
          kgen_isverified = .FALSE. 
      ELSE 
          WRITE (*, *) "Verification PASSED" 
          check_status%Passed = .TRUE. 
          kgen_isverified = .TRUE. 
      END IF   
      WRITE (*, *) "" 
        
      !!Measuring elapsed time. Please increase the value of kgen_maxiter to get improve timing measurment resolution. 
      !CALL SYSTEM_CLOCK(kgen_start_clock, kgen_rate_clock) 
      !DO kgen_intvar = 1, kgen_maxiter 
      !call atm_advance_acoustic_step_work(nCells, nEdges, nCellsSolve, cellStart, cellEnd, vertexStart, vertexEnd, edgeStart, edgeEnd, &
       !                            cellSolveStart, cellSolveEnd, vertexSolveStart, vertexSolveEnd, edgeSolveStart, edgeSolveEnd, &
        !                           rho_zz, theta_m, ru_p, rw_p, rtheta_pp, rtheta_pp_old, zz, exner, cqu, ruAvg, wwAvg, &
         !                          rho_pp, cofwt, coftz, zxu, a_tri, alpha_tri, gamma_tri, dss, tend_ru, tend_rho, tend_rt, &
          !                         tend_rw, zgrid, cofwr, cofwz, w, ru, ru_save, rw, rw_save, fzm, fzp, rdzw, dcEdge, invDcEdge, &
           !                        invAreaCell, cofrz, dvEdge, nEdgesOnCell, cellsOnEdge, edgesOnCell, edgesOnCell_sign, &
           !                        dts, small_step, epssm, cf1, cf2, cf3 &
      !                             )
     ! END DO   
     ! CALL SYSTEM_CLOCK(kgen_stop_clock, kgen_rate_clock) 
     ! kgen_elapsed_time = 1.0e6*(kgen_stop_clock - kgen_start_clock)/REAL(kgen_rate_clock*kgen_maxiter) 
     ! WRITE (*, *) "atm_advance_acoustic_step_work : Time per call (usec): ", kgen_elapsed_time 
        
      CONTAINS 
        
      !read state subroutine for kr_atm_advance_acoustic_step_real__rkind_dim2_ptr 
      SUBROUTINE kr_atm_advance_acoustic_step_real__rkind_dim2_ptr(var, kgen_unit, printvar) 
          REAL(KIND=rkind), INTENT(INOUT), POINTER, DIMENSION(:,:) :: var 
          INTEGER, INTENT(IN) :: kgen_unit 
          CHARACTER(LEN=*), INTENT(IN), OPTIONAL :: printvar 
          LOGICAL :: kgen_istrue 
          REAL(KIND=8) :: kgen_array_sum 
          INTEGER :: idx1, idx2 
          INTEGER, DIMENSION(2,2) :: kgen_bound 
            
          READ (UNIT = kgen_unit) kgen_istrue 
          IF (kgen_istrue) THEN 
              IF (ASSOCIATED( var )) THEN 
                  NULLIFY (var) 
              END IF   
              READ (UNIT = kgen_unit) kgen_array_sum 
              READ (UNIT = kgen_unit) kgen_bound(1, 1) 
              READ (UNIT = kgen_unit) kgen_bound(2, 1) 
              READ (UNIT = kgen_unit) kgen_bound(1, 2) 
              READ (UNIT = kgen_unit) kgen_bound(2, 2) 
              ALLOCATE (var(kgen_bound(1,1):kgen_bound(2,1), kgen_bound(1,2):kgen_bound(2,2))) 
              READ (UNIT = kgen_unit) var 
              IF (PRESENT( printvar )) THEN 
                  CALL kgen_array_sumcheck(printvar, kgen_array_sum, REAL(SUM(var, mask=(var .eq. var)), 8), .TRUE.) 
                  WRITE (*, *) "** KGEN DEBUG: " // printvar // "**" // NEW_LINE("A"), var 
              ELSE 
                  CALL kgen_array_sumcheck("UNKNOWN", kgen_array_sum, REAL(SUM(var, mask=(var .eq. var)), 8), .TRUE.) 
              END IF   
          END IF   
      END SUBROUTINE kr_atm_advance_acoustic_step_real__rkind_dim2_ptr 
        
      !read state subroutine for kr_atm_advance_acoustic_step_real__rkind_dim1_ptr 
      SUBROUTINE kr_atm_advance_acoustic_step_real__rkind_dim1_ptr(var, kgen_unit, printvar) 
          REAL(KIND=rkind), INTENT(INOUT), POINTER, DIMENSION(:) :: var 
          INTEGER, INTENT(IN) :: kgen_unit 
          CHARACTER(LEN=*), INTENT(IN), OPTIONAL :: printvar 
          LOGICAL :: kgen_istrue 
          REAL(KIND=8) :: kgen_array_sum 
          INTEGER :: idx1 
          INTEGER, DIMENSION(2,1) :: kgen_bound 
            
          READ (UNIT = kgen_unit) kgen_istrue 
          IF (kgen_istrue) THEN 
              IF (ASSOCIATED( var )) THEN 
                  NULLIFY (var) 
              END IF   
              READ (UNIT = kgen_unit) kgen_array_sum 
              READ (UNIT = kgen_unit) kgen_bound(1, 1) 
              READ (UNIT = kgen_unit) kgen_bound(2, 1) 
              ALLOCATE (var(kgen_bound(1,1):kgen_bound(2,1))) 
              READ (UNIT = kgen_unit) var 
              IF (PRESENT( printvar )) THEN 
                  CALL kgen_array_sumcheck(printvar, kgen_array_sum, REAL(SUM(var, mask=(var .eq. var)), 8), .TRUE.) 
                  WRITE (*, *) "** KGEN DEBUG: " // printvar // "**" // NEW_LINE("A"), var 
              ELSE 
                  CALL kgen_array_sumcheck("UNKNOWN", kgen_array_sum, REAL(SUM(var, mask=(var .eq. var)), 8), .TRUE.) 
              END IF   
          END IF   
      END SUBROUTINE kr_atm_advance_acoustic_step_real__rkind_dim1_ptr 
        
      !read state subroutine for kr_atm_advance_acoustic_step_integer___dim1_ptr 
      SUBROUTINE kr_atm_advance_acoustic_step_integer___dim1_ptr(var, kgen_unit, printvar) 
          INTEGER, INTENT(INOUT), POINTER, DIMENSION(:) :: var 
          INTEGER, INTENT(IN) :: kgen_unit 
          CHARACTER(LEN=*), INTENT(IN), OPTIONAL :: printvar 
          LOGICAL :: kgen_istrue 
          REAL(KIND=8) :: kgen_array_sum 
          INTEGER :: idx1 
          INTEGER, DIMENSION(2,1) :: kgen_bound 
            
          READ (UNIT = kgen_unit) kgen_istrue 
          IF (kgen_istrue) THEN 
              IF (ASSOCIATED( var )) THEN 
                  NULLIFY (var) 
              END IF   
              READ (UNIT = kgen_unit) kgen_array_sum 
              READ (UNIT = kgen_unit) kgen_bound(1, 1) 
              READ (UNIT = kgen_unit) kgen_bound(2, 1) 
              ALLOCATE (var(kgen_bound(1,1):kgen_bound(2,1))) 
              READ (UNIT = kgen_unit) var 
              IF (PRESENT( printvar )) THEN 
                  CALL kgen_array_sumcheck(printvar, kgen_array_sum, REAL(SUM(var), 8), .TRUE.) 
                  WRITE (*, *) "** KGEN DEBUG: " // printvar // "**" // NEW_LINE("A"), var 
              ELSE 
                  CALL kgen_array_sumcheck("UNKNOWN", kgen_array_sum, REAL(SUM(var), 8), .TRUE.) 
              END IF   
          END IF   
      END SUBROUTINE kr_atm_advance_acoustic_step_integer___dim1_ptr 
        
      !read state subroutine for kr_atm_advance_acoustic_step_integer___dim2_ptr 
      SUBROUTINE kr_atm_advance_acoustic_step_integer___dim2_ptr(var, kgen_unit, printvar) 
          INTEGER, INTENT(INOUT), POINTER, DIMENSION(:,:) :: var 
          INTEGER, INTENT(IN) :: kgen_unit 
          CHARACTER(LEN=*), INTENT(IN), OPTIONAL :: printvar 
          LOGICAL :: kgen_istrue 
          REAL(KIND=8) :: kgen_array_sum 
          INTEGER :: idx1, idx2 
          INTEGER, DIMENSION(2,2) :: kgen_bound 
            
          READ (UNIT = kgen_unit) kgen_istrue 
          IF (kgen_istrue) THEN 
              IF (ASSOCIATED( var )) THEN 
                  NULLIFY (var) 
              END IF   
              READ (UNIT = kgen_unit) kgen_array_sum 
              READ (UNIT = kgen_unit) kgen_bound(1, 1) 
              READ (UNIT = kgen_unit) kgen_bound(2, 1) 
              READ (UNIT = kgen_unit) kgen_bound(1, 2) 
              READ (UNIT = kgen_unit) kgen_bound(2, 2) 
              ALLOCATE (var(kgen_bound(1,1):kgen_bound(2,1), kgen_bound(1,2):kgen_bound(2,2))) 
              READ (UNIT = kgen_unit) var 
              IF (PRESENT( printvar )) THEN 
                  CALL kgen_array_sumcheck(printvar, kgen_array_sum, REAL(SUM(var), 8), .TRUE.) 
                  WRITE (*, *) "** KGEN DEBUG: " // printvar // "**" // NEW_LINE("A"), var 
              ELSE 
                  CALL kgen_array_sumcheck("UNKNOWN", kgen_array_sum, REAL(SUM(var), 8), .TRUE.) 
              END IF   
          END IF   
      END SUBROUTINE kr_atm_advance_acoustic_step_integer___dim2_ptr 
        
      !read state subroutine for kr_atm_advance_acoustic_step_real__rkind_ptr 
      SUBROUTINE kr_atm_advance_acoustic_step_real__rkind_ptr(var, kgen_unit, printvar) 
          REAL(KIND=rkind), INTENT(INOUT), POINTER :: var 
          INTEGER, INTENT(IN) :: kgen_unit 
          CHARACTER(LEN=*), INTENT(IN), OPTIONAL :: printvar 
          LOGICAL :: kgen_istrue 
          REAL(KIND=8) :: kgen_array_sum 
            
          READ (UNIT = kgen_unit) kgen_istrue 
          IF (kgen_istrue) THEN 
              IF (ASSOCIATED( var )) THEN 
                  NULLIFY (var) 
              END IF   
              ALLOCATE (var) 
              READ (UNIT = kgen_unit) var 
              IF (PRESENT( printvar )) THEN 
                  WRITE (*, *) "** KGEN DEBUG: " // printvar // "**" // NEW_LINE("A"), var 
              END IF   
          END IF   
      END SUBROUTINE kr_atm_advance_acoustic_step_real__rkind_ptr 
        
      !read state subroutine for kr_atm_advance_acoustic_step_integer___ptr 
      SUBROUTINE kr_atm_advance_acoustic_step_integer___ptr(var, kgen_unit, printvar) 
          INTEGER, INTENT(INOUT), POINTER :: var 
          INTEGER, INTENT(IN) :: kgen_unit 
          CHARACTER(LEN=*), INTENT(IN), OPTIONAL :: printvar 
          LOGICAL :: kgen_istrue 
          REAL(KIND=8) :: kgen_array_sum 
            
          READ (UNIT = kgen_unit) kgen_istrue 
          IF (kgen_istrue) THEN 
              IF (ASSOCIATED( var )) THEN 
                  NULLIFY (var) 
              END IF   
              ALLOCATE (var) 
              READ (UNIT = kgen_unit) var 
              IF (PRESENT( printvar )) THEN 
                  WRITE (*, *) "** KGEN DEBUG: " // printvar // "**" // NEW_LINE("A"), var 
              END IF   
          END IF   
      END SUBROUTINE kr_atm_advance_acoustic_step_integer___ptr 
        
      !verify state subroutine for kv_atm_advance_acoustic_step_real__rkind_dim2_ptr 
      RECURSIVE SUBROUTINE kv_atm_advance_acoustic_step_real__rkind_dim2_ptr(varname, check_status, var, kgenref_var) 
          CHARACTER(LEN=*), INTENT(IN) :: varname 
          TYPE(check_t), INTENT(INOUT) :: check_status 
          REAL(KIND=rkind), pointer, INTENT(IN), DIMENSION(:,:) :: var, kgenref_var 
          INTEGER :: check_result 
          LOGICAL :: is_print = .FALSE. 
            
          INTEGER :: idx1, idx2 
          INTEGER :: n 
          real(KIND=rkind) :: nrmsdiff, rmsdiff 
          real(KIND=rkind), ALLOCATABLE :: buf1(:,:), buf2(:,:) 
            
          IF (ASSOCIATED(var)) THEN 
              check_status%numTotal = check_status%numTotal + 1 
                
              IF (ALL(var == kgenref_var)) THEN 
                  check_status%numIdentical = check_status%numIdentical + 1 
                  IF (check_status%verboseLevel > 1) THEN 
                      WRITE (*, *) trim(adjustl(varname)), " is IDENTICAL." 
                  END IF   
                  check_result = CHECK_IDENTICAL 
              ELSE 
                  ALLOCATE (buf1(SIZE(var,dim=1),SIZE(var,dim=2))) 
                  ALLOCATE (buf2(SIZE(var,dim=1),SIZE(var,dim=2))) 
                  n = COUNT(var /= kgenref_var) 
                  WHERE ( ABS(kgenref_var) > check_status%minvalue ) 
                      buf1 = ((var-kgenref_var)/kgenref_var)**2 
                      buf2 = (var-kgenref_var)**2 
                  ELSEWHERE 
                      buf1 = (var-kgenref_var)**2 
                      buf2 = buf1 
                  END WHERE   
                  nrmsdiff = SQRT(SUM(buf1)/REAL(n)) 
                  rmsdiff = SQRT(SUM(buf2)/REAL(n)) 
                  IF (nrmsdiff > check_status%tolerance) THEN 
                      check_status%numOutTol = check_status%numOutTol + 1 
                      IF (check_status%verboseLevel > 0) THEN 
                          WRITE (*, *) trim(adjustl(varname)), " is NOT IDENTICAL(out of tolerance)." 
                      END IF   
                      check_result = CHECK_OUT_TOL 
                  ELSE 
                      check_status%numInTol = check_status%numInTol + 1 
                      IF (check_status%verboseLevel > 0) THEN 
                          WRITE (*, *) trim(adjustl(varname)), " is NOT IDENTICAL(within tolerance)." 
                      END IF   
                      check_result = CHECK_IN_TOL 
                  END IF   
              END IF   
              IF (check_result == CHECK_IDENTICAL) THEN 
                  IF (check_status%verboseLevel > 2) THEN 
                      WRITE (*, *) count( var /= kgenref_var), " of ", size( var ), " elements are different." 
                      WRITE (*, *) "Average - kernel ", sum(var)/real(size(var)) 
                      WRITE (*, *) "Average - reference ", sum(kgenref_var)/real(size(kgenref_var)) 
                      WRITE (*, *) "RMS of difference is ", 0 
                      WRITE (*, *) "Normalized RMS of difference is ", 0 
                      WRITE (*, *) "" 
                  END IF   
              ELSE IF (check_result == CHECK_OUT_TOL) THEN 
                  IF (check_status%verboseLevel > 0) THEN 
                      WRITE (*, *) count( var /= kgenref_var), " of ", size( var ), " elements are different." 
                      WRITE (*, *) "Average - kernel ", sum(var)/real(size(var)) 
                      WRITE (*, *) "Average - reference ", sum(kgenref_var)/real(size(kgenref_var)) 
                      WRITE (*, *) "RMS of difference is ", rmsdiff 
                      WRITE (*, *) "Normalized RMS of difference is ", nrmsdiff 
                      WRITE (*, *) "" 
                  END IF   
              ELSE IF (check_result == CHECK_IN_TOL) THEN 
                  IF (check_status%verboseLevel > 1) THEN 
                      WRITE (*, *) count( var /= kgenref_var), " of ", size( var ), " elements are different." 
                      WRITE (*, *) "Average - kernel ", sum(var)/real(size(var)) 
                      WRITE (*, *) "Average - reference ", sum(kgenref_var)/real(size(kgenref_var)) 
                      WRITE (*, *) "RMS of difference is ", rmsdiff 
                      WRITE (*, *) "Normalized RMS of difference is ", nrmsdiff 
                      WRITE (*, *) "" 
                  END IF   
              END IF   
                
          END IF   
      END SUBROUTINE kv_atm_advance_acoustic_step_real__rkind_dim2_ptr 
        
      !verify state subroutine for kv_atm_advance_acoustic_step_real__rkind_dim1_ptr 
      RECURSIVE SUBROUTINE kv_atm_advance_acoustic_step_real__rkind_dim1_ptr(varname, check_status, var, kgenref_var) 
          CHARACTER(LEN=*), INTENT(IN) :: varname 
          TYPE(check_t), INTENT(INOUT) :: check_status 
          REAL(KIND=rkind), pointer, INTENT(IN), DIMENSION(:) :: var, kgenref_var 
          INTEGER :: check_result 
          LOGICAL :: is_print = .FALSE. 
            
          INTEGER :: idx1 
          INTEGER :: n 
          real(KIND=rkind) :: nrmsdiff, rmsdiff 
          real(KIND=rkind), ALLOCATABLE :: buf1(:), buf2(:) 
            
          IF (ASSOCIATED(var)) THEN 
              check_status%numTotal = check_status%numTotal + 1 
                
              IF (ALL(var == kgenref_var)) THEN 
                  check_status%numIdentical = check_status%numIdentical + 1 
                  IF (check_status%verboseLevel > 1) THEN 
                      WRITE (*, *) trim(adjustl(varname)), " is IDENTICAL." 
                  END IF   
                  check_result = CHECK_IDENTICAL 
              ELSE 
                  ALLOCATE (buf1(SIZE(var,dim=1))) 
                  ALLOCATE (buf2(SIZE(var,dim=1))) 
                  n = COUNT(var /= kgenref_var) 
                  WHERE ( ABS(kgenref_var) > check_status%minvalue ) 
                      buf1 = ((var-kgenref_var)/kgenref_var)**2 
                      buf2 = (var-kgenref_var)**2 
                  ELSEWHERE 
                      buf1 = (var-kgenref_var)**2 
                      buf2 = buf1 
                  END WHERE   
                  nrmsdiff = SQRT(SUM(buf1)/REAL(n)) 
                  rmsdiff = SQRT(SUM(buf2)/REAL(n)) 
                  IF (nrmsdiff > check_status%tolerance) THEN 
                      check_status%numOutTol = check_status%numOutTol + 1 
                      IF (check_status%verboseLevel > 0) THEN 
                          WRITE (*, *) trim(adjustl(varname)), " is NOT IDENTICAL(out of tolerance)." 
                      END IF   
                      check_result = CHECK_OUT_TOL 
                  ELSE 
                      check_status%numInTol = check_status%numInTol + 1 
                      IF (check_status%verboseLevel > 0) THEN 
                          WRITE (*, *) trim(adjustl(varname)), " is NOT IDENTICAL(within tolerance)." 
                      END IF   
                      check_result = CHECK_IN_TOL 
                  END IF   
              END IF   
              IF (check_result == CHECK_IDENTICAL) THEN 
                  IF (check_status%verboseLevel > 2) THEN 
                      WRITE (*, *) count( var /= kgenref_var), " of ", size( var ), " elements are different." 
                      WRITE (*, *) "Average - kernel ", sum(var)/real(size(var)) 
                      WRITE (*, *) "Average - reference ", sum(kgenref_var)/real(size(kgenref_var)) 
                      WRITE (*, *) "RMS of difference is ", 0 
                      WRITE (*, *) "Normalized RMS of difference is ", 0 
                      WRITE (*, *) "" 
                  END IF   
              ELSE IF (check_result == CHECK_OUT_TOL) THEN 
                  IF (check_status%verboseLevel > 0) THEN 
                      WRITE (*, *) count( var /= kgenref_var), " of ", size( var ), " elements are different." 
                      WRITE (*, *) "Average - kernel ", sum(var)/real(size(var)) 
                      WRITE (*, *) "Average - reference ", sum(kgenref_var)/real(size(kgenref_var)) 
                      WRITE (*, *) "RMS of difference is ", rmsdiff 
                      WRITE (*, *) "Normalized RMS of difference is ", nrmsdiff 
                      WRITE (*, *) "" 
                  END IF   
              ELSE IF (check_result == CHECK_IN_TOL) THEN 
                  IF (check_status%verboseLevel > 1) THEN 
                      WRITE (*, *) count( var /= kgenref_var), " of ", size( var ), " elements are different." 
                      WRITE (*, *) "Average - kernel ", sum(var)/real(size(var)) 
                      WRITE (*, *) "Average - reference ", sum(kgenref_var)/real(size(kgenref_var)) 
                      WRITE (*, *) "RMS of difference is ", rmsdiff 
                      WRITE (*, *) "Normalized RMS of difference is ", nrmsdiff 
                      WRITE (*, *) "" 
                  END IF   
              END IF   
                
          END IF   
      END SUBROUTINE kv_atm_advance_acoustic_step_real__rkind_dim1_ptr 
        
      !verify state subroutine for kv_atm_advance_acoustic_step_integer___dim1_ptr 
      RECURSIVE SUBROUTINE kv_atm_advance_acoustic_step_integer___dim1_ptr(varname, check_status, var, kgenref_var) 
          CHARACTER(LEN=*), INTENT(IN) :: varname 
          TYPE(check_t), INTENT(INOUT) :: check_status 
          INTEGER, pointer, INTENT(IN), DIMENSION(:) :: var, kgenref_var 
          INTEGER :: check_result 
          LOGICAL :: is_print = .FALSE. 
            
          INTEGER :: idx1 
          INTEGER :: n 
          integer :: nrmsdiff, rmsdiff 
          integer, ALLOCATABLE :: buf1(:), buf2(:) 
            
          IF (ASSOCIATED(var)) THEN 
              check_status%numTotal = check_status%numTotal + 1 
                
              IF (ALL(var == kgenref_var)) THEN 
                  check_status%numIdentical = check_status%numIdentical + 1 
                  IF (check_status%verboseLevel > 1) THEN 
                      WRITE (*, *) trim(adjustl(varname)), " is IDENTICAL." 
                  END IF   
                  check_result = CHECK_IDENTICAL 
              ELSE 
                  ALLOCATE (buf1(SIZE(var,dim=1))) 
                  ALLOCATE (buf2(SIZE(var,dim=1))) 
                  n = COUNT(var /= kgenref_var) 
                  WHERE ( ABS(kgenref_var) > check_status%minvalue ) 
                      buf1 = ((var-kgenref_var)/kgenref_var)**2 
                      buf2 = (var-kgenref_var)**2 
                  ELSEWHERE 
                      buf1 = (var-kgenref_var)**2 
                      buf2 = buf1 
                  END WHERE   
                  nrmsdiff = SQRT(SUM(buf1)/REAL(n)) 
                  rmsdiff = SQRT(SUM(buf2)/REAL(n)) 
                  IF (nrmsdiff > check_status%tolerance) THEN 
                      check_status%numOutTol = check_status%numOutTol + 1 
                      IF (check_status%verboseLevel > 0) THEN 
                          WRITE (*, *) trim(adjustl(varname)), " is NOT IDENTICAL(out of tolerance)." 
                      END IF   
                      check_result = CHECK_OUT_TOL 
                  ELSE 
                      check_status%numInTol = check_status%numInTol + 1 
                      IF (check_status%verboseLevel > 0) THEN 
                          WRITE (*, *) trim(adjustl(varname)), " is NOT IDENTICAL(within tolerance)." 
                      END IF   
                      check_result = CHECK_IN_TOL 
                  END IF   
              END IF   
              IF (check_result == CHECK_IDENTICAL) THEN 
                  IF (check_status%verboseLevel > 2) THEN 
                      WRITE (*, *) count( var /= kgenref_var), " of ", size( var ), " elements are different." 
                      WRITE (*, *) "Average - kernel ", sum(var)/real(size(var)) 
                      WRITE (*, *) "Average - reference ", sum(kgenref_var)/real(size(kgenref_var)) 
                      WRITE (*, *) "RMS of difference is ", 0 
                      WRITE (*, *) "Normalized RMS of difference is ", 0 
                      WRITE (*, *) "" 
                  END IF   
              ELSE IF (check_result == CHECK_OUT_TOL) THEN 
                  IF (check_status%verboseLevel > 0) THEN 
                      WRITE (*, *) count( var /= kgenref_var), " of ", size( var ), " elements are different." 
                      WRITE (*, *) "Average - kernel ", sum(var)/real(size(var)) 
                      WRITE (*, *) "Average - reference ", sum(kgenref_var)/real(size(kgenref_var)) 
                      WRITE (*, *) "RMS of difference is ", rmsdiff 
                      WRITE (*, *) "Normalized RMS of difference is ", nrmsdiff 
                      WRITE (*, *) "" 
                  END IF   
              ELSE IF (check_result == CHECK_IN_TOL) THEN 
                  IF (check_status%verboseLevel > 1) THEN 
                      WRITE (*, *) count( var /= kgenref_var), " of ", size( var ), " elements are different." 
                      WRITE (*, *) "Average - kernel ", sum(var)/real(size(var)) 
                      WRITE (*, *) "Average - reference ", sum(kgenref_var)/real(size(kgenref_var)) 
                      WRITE (*, *) "RMS of difference is ", rmsdiff 
                      WRITE (*, *) "Normalized RMS of difference is ", nrmsdiff 
                      WRITE (*, *) "" 
                  END IF   
              END IF   
                
          END IF   
      END SUBROUTINE kv_atm_advance_acoustic_step_integer___dim1_ptr 
        
      !verify state subroutine for kv_atm_advance_acoustic_step_integer___dim2_ptr 
      RECURSIVE SUBROUTINE kv_atm_advance_acoustic_step_integer___dim2_ptr(varname, check_status, var, kgenref_var) 
          CHARACTER(LEN=*), INTENT(IN) :: varname 
          TYPE(check_t), INTENT(INOUT) :: check_status 
          INTEGER, pointer, INTENT(IN), DIMENSION(:,:) :: var, kgenref_var 
          INTEGER :: check_result 
          LOGICAL :: is_print = .FALSE. 
            
          INTEGER :: idx1, idx2 
          INTEGER :: n 
          integer :: nrmsdiff, rmsdiff 
          integer, ALLOCATABLE :: buf1(:,:), buf2(:,:) 
            
          IF (ASSOCIATED(var)) THEN 
              check_status%numTotal = check_status%numTotal + 1 
                
              IF (ALL(var == kgenref_var)) THEN 
                  check_status%numIdentical = check_status%numIdentical + 1 
                  IF (check_status%verboseLevel > 1) THEN 
                      WRITE (*, *) trim(adjustl(varname)), " is IDENTICAL." 
                  END IF   
                  check_result = CHECK_IDENTICAL 
              ELSE 
                  ALLOCATE (buf1(SIZE(var,dim=1),SIZE(var,dim=2))) 
                  ALLOCATE (buf2(SIZE(var,dim=1),SIZE(var,dim=2))) 
                  n = COUNT(var /= kgenref_var) 
                  WHERE ( ABS(kgenref_var) > check_status%minvalue ) 
                      buf1 = ((var-kgenref_var)/kgenref_var)**2 
                      buf2 = (var-kgenref_var)**2 
                  ELSEWHERE 
                      buf1 = (var-kgenref_var)**2 
                      buf2 = buf1 
                  END WHERE   
                  nrmsdiff = SQRT(SUM(buf1)/REAL(n)) 
                  rmsdiff = SQRT(SUM(buf2)/REAL(n)) 
                  IF (nrmsdiff > check_status%tolerance) THEN 
                      check_status%numOutTol = check_status%numOutTol + 1 
                      IF (check_status%verboseLevel > 0) THEN 
                          WRITE (*, *) trim(adjustl(varname)), " is NOT IDENTICAL(out of tolerance)." 
                      END IF   
                      check_result = CHECK_OUT_TOL 
                  ELSE 
                      check_status%numInTol = check_status%numInTol + 1 
                      IF (check_status%verboseLevel > 0) THEN 
                          WRITE (*, *) trim(adjustl(varname)), " is NOT IDENTICAL(within tolerance)." 
                      END IF   
                      check_result = CHECK_IN_TOL 
                  END IF   
              END IF   
              IF (check_result == CHECK_IDENTICAL) THEN 
                  IF (check_status%verboseLevel > 2) THEN 
                      WRITE (*, *) count( var /= kgenref_var), " of ", size( var ), " elements are different." 
                      WRITE (*, *) "Average - kernel ", sum(var)/real(size(var)) 
                      WRITE (*, *) "Average - reference ", sum(kgenref_var)/real(size(kgenref_var)) 
                      WRITE (*, *) "RMS of difference is ", 0 
                      WRITE (*, *) "Normalized RMS of difference is ", 0 
                      WRITE (*, *) "" 
                  END IF   
              ELSE IF (check_result == CHECK_OUT_TOL) THEN 
                  IF (check_status%verboseLevel > 0) THEN 
                      WRITE (*, *) count( var /= kgenref_var), " of ", size( var ), " elements are different." 
                      WRITE (*, *) "Average - kernel ", sum(var)/real(size(var)) 
                      WRITE (*, *) "Average - reference ", sum(kgenref_var)/real(size(kgenref_var)) 
                      WRITE (*, *) "RMS of difference is ", rmsdiff 
                      WRITE (*, *) "Normalized RMS of difference is ", nrmsdiff 
                      WRITE (*, *) "" 
                  END IF   
              ELSE IF (check_result == CHECK_IN_TOL) THEN 
                  IF (check_status%verboseLevel > 1) THEN 
                      WRITE (*, *) count( var /= kgenref_var), " of ", size( var ), " elements are different." 
                      WRITE (*, *) "Average - kernel ", sum(var)/real(size(var)) 
                      WRITE (*, *) "Average - reference ", sum(kgenref_var)/real(size(kgenref_var)) 
                      WRITE (*, *) "RMS of difference is ", rmsdiff 
                      WRITE (*, *) "Normalized RMS of difference is ", nrmsdiff 
                      WRITE (*, *) "" 
                  END IF   
              END IF   
                
          END IF   
      END SUBROUTINE kv_atm_advance_acoustic_step_integer___dim2_ptr 
        
   END SUBROUTINE atm_advance_acoustic_step 


   subroutine atm_advance_acoustic_step_work(nCells, nEdges, nCellsSolve, cellStart, cellEnd, vertexStart, vertexEnd, edgeStart, edgeEnd, &
                                   cellSolveStart, cellSolveEnd, vertexSolveStart, vertexSolveEnd, edgeSolveStart, edgeSolveEnd, &
                                   rho_zz, theta_m, ru_p, rw_p, rtheta_pp, rtheta_pp_old, zz, exner, cqu, ruAvg, wwAvg, &
                                   rho_pp, cofwt, coftz, zxu, a_tri, alpha_tri, gamma_tri, dss, tend_ru, tend_rho, tend_rt, &
                                   tend_rw, zgrid, cofwr, cofwz, w, ru, ru_save, rw, rw_save, fzm, fzp, rdzw, dcEdge, invDcEdge, &
                                   invAreaCell, cofrz, dvEdge, nEdgesOnCell, cellsOnEdge, edgesOnCell, edgesOnCell_sign, &
                                   dts, small_step, epssm, cf1, cf2, cf3 &
                                   )

       USE mpas_atm_dimensions 

      implicit none


      !
      ! Dummy arguments
      !
      integer, intent(in) :: nCells, nEdges, nCellsSolve
      integer, intent(in) :: cellStart, cellEnd, vertexStart, vertexEnd, edgeStart, edgeEnd
      integer, intent(in) :: cellSolveStart, cellSolveEnd, vertexSolveStart, vertexSolveEnd, edgeSolveStart, edgeSolveEnd

      real (kind=RKIND), dimension(nVertLevels,nCells+1) :: rho_zz
      real (kind=RKIND), dimension(nVertLevels,nCells+1) :: theta_m
      real (kind=RKIND), dimension(nVertLevels,nEdges+1) :: ru_p
      real (kind=RKIND), dimension(nVertLevels+1,nCells+1) :: rw_p
      real (kind=RKIND), dimension(nVertLevels,nCells+1) :: rtheta_pp

      real (kind=RKIND), dimension(nVertLevels,nCells+1) :: rtheta_pp_old
      real (kind=RKIND), dimension(nVertLevels,nCells+1) :: zz
      real (kind=RKIND), dimension(nVertLevels,nCells+1) :: exner
      real (kind=RKIND), dimension(nVertLevels,nEdges+1) :: cqu
      real (kind=RKIND), dimension(nVertLevels,nEdges+1) :: ruAvg
      real (kind=RKIND), dimension(nVertLevels+1,nCells+1) :: wwAvg
      real (kind=RKIND), dimension(nVertLevels,nCells+1) :: rho_pp
      real (kind=RKIND), dimension(nVertLevels,nCells+1) :: cofwt
      real (kind=RKIND), dimension(nVertLevels+1,nCells+1) :: coftz
      real (kind=RKIND), dimension(nVertLevels,nEdges+1) :: zxu

      real (kind=RKIND), dimension(nVertLevels,nCells+1) :: a_tri
      real (kind=RKIND), dimension(nVertLevels,nCells+1) :: alpha_tri
      real (kind=RKIND), dimension(nVertLevels,nCells+1) :: gamma_tri
      real (kind=RKIND), dimension(nVertLevels,nCells+1) :: dss
      real (kind=RKIND), dimension(nVertLevels,nEdges+1) :: tend_ru
      real (kind=RKIND), dimension(nVertLevels,nCells+1) :: tend_rho
      real (kind=RKIND), dimension(nVertLevels,nCells+1) :: tend_rt
      real (kind=RKIND), dimension(nVertLevels+1,nCells+1) :: tend_rw
      real (kind=RKIND), dimension(nVertLevels+1,nCells+1) :: zgrid
      real (kind=RKIND), dimension(nVertLevels,nCells+1) :: cofwr
      real (kind=RKIND), dimension(nVertLevels,nCells+1) :: cofwz

      real (kind=RKIND), dimension(nVertLevels+1,nCells+1) :: w
      real (kind=RKIND), dimension(nVertLevels,nEdges+1) :: ru
      real (kind=RKIND), dimension(nVertLevels,nEdges+1) :: ru_save
      real (kind=RKIND), dimension(nVertLevels+1,nCells+1) :: rw
      real (kind=RKIND), dimension(nVertLevels+1,nCells+1) :: rw_save

      real (kind=RKIND), dimension(nVertLevels) :: fzm
      real (kind=RKIND), dimension(nVertLevels) :: fzp
      real (kind=RKIND), dimension(nVertLevels) :: rdzw
      real (kind=RKIND), dimension(nEdges+1) :: dcEdge
      real (kind=RKIND), dimension(nEdges+1) :: invDcEdge
      real (kind=RKIND), dimension(nCells+1) :: invAreaCell
      real (kind=RKIND), dimension(nVertLevels) :: cofrz
      real (kind=RKIND), dimension(nEdges+1) :: dvEdge

      integer, dimension(nCells+1) :: nEdgesOnCell
      integer, dimension(2,nEdges+1) :: cellsOnEdge
      integer, dimension(maxEdges,nCells+1) :: edgesOnCell
      real (kind=RKIND), dimension(maxEdges,nCells+1) :: edgesOnCell_sign

      integer, intent(in) :: small_step
      real (kind=RKIND), intent(in) :: dts, epssm,cf1, cf2, cf3
      real (kind=RKIND), dimension(nVertLevels) :: ts, rs

  
      !
      ! Local variables
      !
      integer :: cell1, cell2, iEdge, iCell, i, k
      real (kind=RKIND) :: c2, rcv, rtheta_pp_tmp
      real (kind=RKIND) :: pgrad, flux, resm, rdts


      rcv = rgas / (cp - rgas)
      c2 = cp * rcv
      resm = (1.0 - epssm) / (1.0 + epssm)
      rdts = 1./dts

      if(small_step /= 1) then  !  not needed on first small step 

        ! forward-backward acoustic step integration.
        ! begin by updating the horizontal velocity u, 
        ! and accumulating the contribution from the updated u to the other tendencies.

        ! we are looping over all edges, but only computing on edges of owned cells. This will include updates of
        ! all owned edges plus some edges that are owned by other blocks.  We perform these redundant computations
        ! so that we do not have to communicate updates of u to update the cell variables (rho, w, and theta). 

        !MGD this loop will not be very load balanced with if-test below
!!$acc parallel num_gangs(256) num_workers(4) vector_length(32)
!!$acc loop gang worker
!$acc kernels 
        do iEdge=edgeStart,edgeEnd ! MGD do we really just need edges touching owned cells?
 
           cell1 = cellsOnEdge(1,iEdge)
           cell2 = cellsOnEdge(2,iEdge)
!!$acc loop vector collapse(2)
           ! update edges for block-owned cells
           if (cell1 <= nCellsSolve .or. cell2 <= nCellsSolve ) then

!DIR$ IVDEP
!!$acc loop vector
              do k=1,nVertLevels
                 pgrad = ((rtheta_pp(k,cell2)-rtheta_pp(k,cell1))*invDcEdge(iEdge) )/(.5*(zz(k,cell2)+zz(k,cell1)))
                 pgrad = cqu(k,iEdge)*0.5*c2*(exner(k,cell1)+exner(k,cell2))*pgrad
                 pgrad = pgrad + 0.5*zxu(k,iEdge)*gravity*(rho_pp(k,cell1)+rho_pp(k,cell2))
                 ru_p(k,iEdge) = ru_p(k,iEdge) + dts*(tend_ru(k,iEdge) - pgrad) 
              end do
!!acc end parallel
              ! accumulate ru_p for use later in scalar transport
!DIR$ IVDEP
              do k=1,nVertLevels
                 ruAvg(k,iEdge) = ruAvg(k,iEdge) + ru_p(k,iEdge)
              end do

           end if ! end test for block-owned cells

        end do ! end loop over edges
!$acc end kernels
      else !  this is all that us needed for ru_p update for first acoustic step in RK substep
!!$acc kernels
        do iEdge=edgeStart,edgeEnd ! MGD do we really just need edges touching owned cells?

           cell1 = cellsOnEdge(1,iEdge)
           cell2 = cellsOnEdge(2,iEdge)

           ! update edges for block-owned cells
           if (cell1 <= nCellsSolve .or. cell2 <= nCellsSolve ) then

!DIR$ IVDEP
              do k=1,nVertLevels
                 ru_p(k,iEdge) = dts*tend_ru(k,iEdge)
              end do
!DIR$ IVDEP
              do k=1,nVertLevels
                 ruAvg(k,iEdge) = ru_p(k,iEdge)                 
              end do

           end if ! end test for block-owned cells
        end do ! end loop over edges
!!$acc end kernels
      end if ! test for first acoustic step
!!$acc kernels
      if (small_step == 1) then  ! initialize here on first small timestep.
         do iCell=cellStart,cellEnd
            rtheta_pp_old(1:nVertLevels,iCell) = 0.0
         end do
      else
         do iCell=cellStart,cellEnd
            rtheta_pp_old(1:nVertLevels,iCell) = rtheta_pp(1:nVertLevels,iCell)
         end do
      end if
!!$acc end kernels
!$OMP BARRIER
!!$acc kernels
      do iCell=cellSolveStart,cellSolveEnd  ! loop over all owned cells to solve

         ts(:) = 0.0
         rs(:) = 0.0

         if(small_step == 1) then  ! initialize here on first small timestep.
            wwAvg(1:nVertLevels+1,iCell) = 0.0            
            rho_pp(1:nVertLevels,iCell) = 0.0            
            rtheta_pp(1:nVertLevels,iCell) = 0.0            
            rw_p(:,iCell) = 0.0
         end if
            
         do i=1,nEdgesOnCell(iCell) 
            iEdge = edgesOnCell(i,iCell)
            cell1 = cellsOnEdge(1,iEdge)
            cell2 = cellsOnEdge(2,iEdge)
!DIR$ IVDEP
            do k=1,nVertLevels
               flux = edgesOnCell_sign(i,iCell)*dts*dvEdge(iEdge)*ru_p(k,iEdge) * invAreaCell(iCell)
               rs(k) = rs(k)-flux
               ts(k) = ts(k)-flux*0.5*(theta_m(k,cell2)+theta_m(k,cell1))
            end do
         end do
!!$acc end kernels
      ! vertically implicit acoustic and gravity wave integration.
      ! this follows Klemp et al MWR 2007, with the addition of an implicit Rayleigh damping of w
      ! serves as a gravity-wave absorbing layer, from Klemp et al 2008.

!DIR$ IVDEP
!!$acc kernels
         do k=1, nVertLevels
            rs(k) = rho_pp(k,iCell) + dts*tend_rho(k,iCell) + rs(k)                  &
                            - cofrz(k)*resm*(rw_p(k+1,iCell)-rw_p(k,iCell)) 
            ts(k) = rtheta_pp(k,iCell) + dts*tend_rt(k,iCell) + ts(k)                &
                               - resm*rdzw(k)*( coftz(k+1,iCell)*rw_p(k+1,iCell)     &
                                               -coftz(k,iCell)*rw_p(k,iCell))
         end do

!DIR$ IVDEP
         do k=2, nVertLevels
            wwavg(k,iCell) = wwavg(k,iCell) + 0.5*(1.0-epssm)*rw_p(k,iCell)
         end do

!DIR$ IVDEP
         do k=2, nVertLevels
            rw_p(k,iCell) = rw_p(k,iCell) +  dts*tend_rw(k,iCell)                       &
                       - cofwz(k,iCell)*((zz(k  ,iCell)*ts(k)                           &
                                     -zz(k-1,iCell)*ts(k-1))                            &
                               +resm*(zz(k  ,iCell)*rtheta_pp(k  ,iCell)                &
                                     -zz(k-1,iCell)*rtheta_pp(k-1,iCell)))              &
                       - cofwr(k,iCell)*((rs(k)+rs(k-1))                                &
                               +resm*(rho_pp(k,iCell)+rho_pp(k-1,iCell)))               &
                       + cofwt(k  ,iCell)*(ts(k  )+resm*rtheta_pp(k  ,iCell))           &
                       + cofwt(k-1,iCell)*(ts(k-1)+resm*rtheta_pp(k-1,iCell))
         end do

         ! tridiagonal solve sweeping up and then down the column

!MGD VECTOR DEPENDENCE
         do k=2,nVertLevels
            rw_p(k,iCell) = (rw_p(k,iCell)-a_tri(k,iCell)*rw_p(k-1,iCell))*alpha_tri(k,iCell)
         end do

!MGD VECTOR DEPENDENCE
         do k=nVertLevels,1,-1
            rw_p(k,iCell) = rw_p(k,iCell) - gamma_tri(k,iCell)*rw_p(k+1,iCell)     
         end do

         ! the implicit Rayleigh damping on w (gravity-wave absorbing) 

!DIR$ IVDEP
         do k=2,nVertLevels
            rw_p(k,iCell) = (rw_p(k,iCell) + (rw_save(k  ,iCell) - rw(k  ,iCell)) -dts*dss(k,iCell)*               &
                        (fzm(k)*zz (k,iCell)+fzp(k)*zz (k-1,iCell))        &
                        *(fzm(k)*rho_zz(k,iCell)+fzp(k)*rho_zz(k-1,iCell))       &
                                 *w(k,iCell)    )/(1.0+dts*dss(k,iCell)) &
                         - (rw_save(k  ,iCell) - rw(k  ,iCell))
         end do

         ! accumulate (rho*omega)' for use later in scalar transport
!DIR$ IVDEP
         do k=2,nVertLevels
            wwAvg(k,iCell) = wwAvg(k,iCell) + 0.5*(1.0+epssm)*rw_p(k,iCell)
         end do

         ! update rho_pp and theta_pp given updated rw_p

!DIR$ IVDEP
         do k=1,nVertLevels
            rho_pp(k,iCell) = rs(k) - cofrz(k) *(rw_p(k+1,iCell)-rw_p(k  ,iCell))
            rtheta_pp(k,iCell) = ts(k) - rdzw(k)*(coftz(k+1,iCell)*rw_p(k+1,iCell)  &
                               -coftz(k  ,iCell)*rw_p(k  ,iCell))
         end do

      end do !  end of loop over cells
!!$acc end kernels
   end subroutine atm_advance_acoustic_step_work


end module atm_time_integration
