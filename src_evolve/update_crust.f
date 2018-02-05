!-------------------------------------------------------------------------
      SUBROUTINE UPDATE_CRUST
!-------------------------------------------------------------------------
! ***  computes the phase equilibrium of crust + the lowest cell of    ***
! ***  atmosphere.  The result is the crust solid composition and the  ***
! ***  element abundances in the gas above the crust.                  ***
!-------------------------------------------------------------------------
      use GRID,ONLY: zz
      use STRUCT,ONLY: Temp,nHtot,nHeps,crust_depth,crust_beta,
     >                 crust_Neps,crust_Ncond,crust_gaseps
      use ELEMENTS,ONLY: NELEM,eps0,elnam
      use CHEMISTRY,ONLY: NMOLE,NELM,elnum,iel=>el
      use DUST_DATA,ONLY: NDUST,dust_vol,dust_nam,
     >                    dust_nel,dust_el,dust_nu
      use EXCHANGE,ONLY: inactive,nmol,chi,H
      implicit none
      integer,parameter  :: qp = selected_real_kind ( 33, 4931 )
      real*8  :: Tg,nH,dz
      real(kind=qp) :: eps(NELEM),Sat(NDUST),eldust(NDUST)
      real(kind=qp) :: sum_beta,Natmos,Ncrust,NtotH,crust_Vol
      integer :: i,j,el,verb,verbose=2

      if (verbose>1) then
        print*
        print*,"entering UPDATE_CRUST ..."
        print*,"========================="
      endif  

      Tg = Temp(0)
      nH = nHtot(0)
      dz = 0.5*(zz(1)-zz(0))
      eps0 = 0.Q0
      NtotH = nH*dz + crust_Neps(H)
      do i=1,NELM
        if (i==iel) cycle
        el = elnum(i)
        Natmos = nHeps(el,0)*dz           ! col.dens. in atmosphere cell
        Ncrust = crust_Neps(el)           ! col.dens. in crust
        eps0(el) = (Natmos+Ncrust)/NtotH
        !print'(A4,2(1pE16.8))',elnam(el),Natmos+Ncrust 
      enddo  
      inactive = .false.
      call EQUIL_COND(nH,Tg,eps,Sat,eldust,verb)

      crust_gaseps(:) = eps(:)            ! element abund. over crust
      crust_Ncond(:) = 0.Q0               ! crust material column densities
      crust_Neps(:) = 0.Q0                ! crust element col.dens
      crust_Vol = 0.Q0
      do i=1,NDUST         
        if (eldust(i).le.0.Q0) cycle 
        crust_Ncond(i) = eldust(i)*NtotH
        crust_Vol = crust_Vol + dust_vol(i)*eldust(i)*NtotH   ! Vol/area
        do j=1,dust_nel(i)
          el = dust_el(i,j)
          crust_Neps(el) =  crust_Neps(el) + dust_nu(i,j)*crust_Ncond(i)
        enddo
      enddo  
      crust_depth = crust_Vol             ! thickness of crust
      if (verbose>1) then
        print*,"crust depth[cm] = ",crust_depth
      endif  

      crust_beta(:) = 0.Q0                ! crust volume composition
      sum_beta = 0.Q0
      do i=1,NDUST
        if (eldust(i).le.0.Q0) cycle
        crust_beta(i) = eldust(i)*dust_vol(i)
        sum_beta = sum_beta + crust_beta(i)
      enddo  
      crust_beta = crust_beta/sum_beta
      nHeps(:,0) = nH*crust_gaseps(:)

      print*
      print'(3x,4(A15))',"eps0","eps","Ngas[cm-2]","Ncrust[cm-2]"
      if (verbose>1) then
        do i=1,NELM
          if (i==iel) cycle
          el = elnum(i)
          print'(A3,4(1pE15.7))',elnam(el),eps0(el),eps(el),
     >         nH*crust_gaseps(el)*dz,crust_Neps(el)
        enddo
      endif  

      end
