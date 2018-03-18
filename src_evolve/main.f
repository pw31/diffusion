
      program DiffuEvo

      use PARAMETERS,ONLY: struc_file,tsim,dt_init,dt_increase,
     >                     dt_max,immediateEnd
      use GRID,ONLY: dt_diff_ex
      use EXCHANGE,ONLY: chemcall,chemiter,ieqcond,ieqconditer,
     >                   itransform
      use DATABASE,ONLY: NLAST
      implicit none
      real*8  :: time,dt
      integer :: it,nout,next
      logical :: reduced

      call INIT_NATURE
      call READ_PARAMETER
      call INIT_ELEMENTS1
      call INIT_CHEMISTRY
      call INIT_DUSTCHEM
      if (struc_file == 'none') then
        call CREATE_STRUCTURE
      else  
        call READ_STRUCTURE
      endif  
      call INIT_ELEMENTS2
      call INIT_GRID
      call INIT_TIMESTEP
      call INIT_CRUST

      nout = 0
      time = 0.d0
      dt   = dt_init
      call INITIAL_CONDITIONS(nout,time,dt)
      if (nout==0) call OUTPUT(nout,time,dt)
      if (immediateEnd) goto 100
      next = nout

      do it=1,300
        print* 
        print'("new timestep",i8,"  Dt=",1pE10.3," ...")',nout,dt 
        call DIFFUSION(time,dt,reduced)
        time = time+dt
        call WARM_UP(time)
        call UPDATE_CRUST
        nout = nout + 1
        if (nout>next) then
          call OUTPUT(nout,time,dt)
          next = nout
          if (.not.reduced) dt = MIN(dt_max,dt*dt_increase)
        endif  
        if (time>tsim) exit
      enddo  
      call OUTPUT(nout,time,dt)

      print*
      print'("         smchem calls = ",I8)',chemcall
      print'("      iterations/call = ",0pF8.2)',
     >                     REAL(chemiter)/REAL(chemcall)
      print'("eq condensation calls = ",I8)',ieqcond
      print'("   eq iterations/call = ",0pF8.2)',
     >                  REAL(ieqconditer)/REAL(ieqcond)
      print'("      transform calls = ",I8)',itransform
      NLAST=0         ! also save replaced database entries
 100  call SAVE_DBASE
      
      end

      
