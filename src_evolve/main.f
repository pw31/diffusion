
      program DiffuEvo

      use NATURE,ONLY: yr
      use PARAMETERS,ONLY: struc_file,tsim,dt_init,dt_increase,
     >                     dt_max,immediateEnd,verbose
      use GRID,ONLY: dt_diff_ex
      use EXCHANGE,ONLY: chemcall,chemiter,ieqcond,ieqconditer,
     >                   itransform
      use ELEMENTS,ONLY: NELEM
      use DATABASE,ONLY: NLAST
      implicit none
      real*8  :: time,dt,tout,tnext
      integer :: nout,it,Nsolve,indep(NELEM)
      character(len=1) :: char
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
      call INIT_CRUST(Nsolve,indep)

      nout  = 0
      time  = 0.d0
      dt    = dt_init
      tnext = time+10.0*dt
      call INITIAL_CONDITIONS(nout,time,tnext,dt)
      if (nout==0) call OUTPUT(nout,time,tnext,dt)
      if (immediateEnd) goto 100

      do it=1,300
        if (verbose>0) then 
          print* 
          print'("new timestep",i8,"  Dt=",1pE10.3," ...")',nout,dt 
        endif  
        call DIFFUSION(time,dt,reduced,Nsolve,indep)
        time = time+dt
        call WARM_UP(time)
        call UPDATE_CRUST(Nsolve,indep)
        if (time>tnext) then
          nout = nout + 1
          tnext = MIN(time+dt_max,time*dt_increase)
          call OUTPUT(nout,time,tnext,dt)
          if (time>tsim) exit
        endif  
        if (.not.reduced) dt = MIN(dt_max,dt*dt_increase)
        print'(I8," timestep completed. time,tnext,dtnew=",3(1pE11.4))',
     >         it,time,tnext,dt
        !read(*,'(A1)') char
      enddo  

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

      
