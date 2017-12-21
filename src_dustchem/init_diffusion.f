************************************************************************
      subroutine INIT_DIFFUSION
************************************************************************
      use GRID,ONLY: N=>Npoints,zz,d1l,d1m,d1r,d2l,d2m,d2r,
     >               BB,dt_diff_ex,dt_diff_im
      use STRUCT,ONLY: nHtot,Diff
      use PARAMETERS,ONLY: tfac,bc_low,bc_high,inrate,outrate,vin,vout
      implicit none
      integer,parameter :: qp = selected_real_kind ( 33, 4931 )
      integer :: i,j,k,ipvt(N),info
      real(kind=qp),dimension(N,N) :: Awork
      real(kind=qp) :: det(2),work(N)
      real*8 :: AA(N,N),sum(N,N)
      real*8 :: df,h1,h2
      real*8 :: D,nD,d1nD,dt,err
      real*8,allocatable,dimension(:) :: hl,hr,f0,f1,f2
      logical :: test=.false.,check=.false.

      allocate(hl(2:N),hr(1:N-1))
      allocate(d1l(1:N),d1m(1:N),d1r(1:N))
      allocate(d2l(1:N),d2m(1:N),d2r(1:N))
      allocate(f0(N),f1(N),f2(N))
      allocate(BB(N,N))

      !--- compute grid point differences ---
      do i=1,N-1
        hr(i) = zz(i+1)-zz(i)
      enddo  
      do i=2,N
        hl(i) = zz(i)-zz(i-1)
      enddo  

      !--- compute 1st and 2nd derivative coefficients ---
      do i=2,N-1
        d1l(i) = -hr(i)/((hr(i)+hl(i))*hl(i))
        d1m(i) =  (hr(i)-hl(i))/(hl(i)*hr(i))
        d1r(i) =  hl(i)/((hr(i)+hl(i))*hr(i)) 
        d2l(i) =  2.0/((hr(i)+hl(i))*hl(i))
        d2m(i) = -2.0/(hr(i)*hl(i))
        d2r(i) =  2.0/((hr(i)+hl(i))*hr(i))
      enddo
      !--- compute 1st derivative coefficients at boundaries ---
      !d1m(1) = -1.d0/hr(1)
      !d1r(1) =  1.d0/hr(1)  ! first order
      h1 = zz(2)-zz(1)
      h2 = zz(3)-zz(1)      
      d1l(1) = -(h1+h2)/(h1*h2)
      d1m(1) =  h2/(h1*(h2-h1))
      d1r(1) = -h1/(h2*(h2-h1))
      !d1l(N) = -1.d0/hl(N)
      !d1m(N) =  1.d0/hl(N)
      h1 = zz(N-1)-zz(N)
      h2 = zz(N-2)-zz(N)      
      d1r(N) = -(h1+h2)/(h1*h2)
      d1m(N) =  h2/(h1*(h2-h1))
      d1l(N) = -h1/(h2*(h2-h1))

      if (test) then
        !--- test derivatives ---
        do i=1,N
          f0(i) = 2.0*zz(i)**2-zz(i)+0.5
          f1(i) = 4.0*zz(i)-1.0
          f2(i) = 4.0
        enddo
        do i=2,N-1
          df = f0(i-1)*d1l(i) + f0(i)*d1m(i) + f0(i+1)*d1r(i)
          print'(I4,3(1pE14.6))',i,f1(i),df,f1(i)-df
        enddo
        do i=2,N-1
          df = f0(i-1)*d2l(i) + f0(i)*d2m(i) + f0(i+1)*d2r(i)
          print'(I4,3(1pE14.6))',i,f2(i),df,f2(i)-df
        enddo
        df = f0(1)*d1l(1) + f0(2)*d1m(1) + f0(3)*d1r(1) 
        print'(I4,3(1pE14.6))',1,f1(1),df,f1(1)-df
        df = f0(N-2)*d1l(N) + f0(N-1)*d1m(N) + f0(N)*d1r(N) 
        print'(I4,3(1pE14.6))',N,f1(N),df,f1(N)-df
        stop
      endif  

      !-------------------
      ! ***  timestep  ***
      !-------------------
      dt = 9.D+99
      do i=2,N
        D  = 0.5*(Diff(i-1)+Diff(i)) 
        dt = MIN(dt,0.5*(zz(i)-zz(i-1))**2/D)
      enddo
      dt_diff_ex = dt
      print*,"explicit diffusion timestep=",dt_diff_ex
      dt_diff_im = dt*tfac
      print*,"implicit diffusion timestep=",dt_diff_im

      !-----------------------------
      ! ***  fill in big matrix  ***
      !-----------------------------
      dt = dt_diff_im
      AA(:,:) = 0.d0
      do i=2,N-1
        nD   = nHtot(i)*Diff(i)  
        d1nD = d1l(i)*nHtot(i-1)*Diff(i-1) 
     >       + d1m(i)*nHtot(i)  *Diff(i) 
     >       + d1r(i)*nHtot(i+1)*Diff(i+1) 
        AA(i,i-1) = AA(i,i-1) - dt*( d1nD*d1l(i) + nD*d2l(i) )
        AA(i,i)   = AA(i,i)   - dt*( d1nD*d1m(i) + nD*d2m(i) )
        AA(i,i+1) = AA(i,i+1) - dt*( d1nD*d1r(i) + nD*d2r(i) )
      enddo
      do i=1,N
        AA(i,:) = AA(i,:)/nHtot(i)    ! unitless
      enddo  
      !--------------------------
      ! ***  add unit matrix  ***
      !--------------------------
      do i=1,N
        AA(i,i) = AA(i,i) + 1.d0
      enddo 
      !------------------------------
      ! ***  boundary conditions  ***
      !------------------------------
      if (bc_low==1) then
        !--- nothing to do 
      else if (bc_low==2) then
        AA(1,1) = 1.d0
        AA(1,2) = d1m(1)/d1l(1)
        AA(1,3) = d1r(1)/d1l(1)
      else if (bc_low==3) then
        AA(1,1) = 1.d0+inrate*vin/Diff(1)/d1l(1) 
        AA(1,2) = d1m(1)/d1l(1)
        AA(1,3) = d1r(1)/d1l(1)
      endif  
      if (bc_high==1) then
        !--- nothing to do 
      else if (bc_high==2) then   
        AA(N,N-2) = d1l(N)/d1r(N)
        AA(N,N-1) = d1m(N)/d1r(N)
        AA(N,N)   = 1.d0
      else if (bc_high==3) then   
        AA(N,N-2) = d1l(N)/d1r(N)
        AA(N,N-1) = d1m(N)/d1r(N)
        AA(N,N)   = 1.d0+outrate*vout/Diff(N)/d1r(N) 
      endif   

      !------------------------
      ! ***  invert matrix  ***
      !------------------------
      Awork = AA
      call QGEFA ( Awork, N, N, ipvt, info )
      call QGEDI ( Awork, N, N, ipvt, det, work, 1 )
      BB = Awork
      if (info.ne.0) then
        print*,"*** singular matrix in QGEFA: info=",info
        stop
      endif   
      if (check) then
        do i=1,N
          write(99,'(9999(1pE11.3))') (AA(i,j),j=1,N)
        enddo
        write(99,*)
        do i=1,N
          write(99,'(9999(1pE11.3))') (BB(i,j),j=1,N)
        enddo
        !--- test A*B=1 ---
        err = 0.d0
        write(99,*)
        do i=1,N
          do j=1,N
            sum(i,j) = 0.d0
            do k=1,N
              sum(i,j) = sum(i,j) + AA(i,k)*BB(k,j)
            enddo 
            if (i==j) then
              err = max(err,ABS(sum(i,j)-1.d0)) 
            else  
              err = max(err,ABS(sum(i,j))) 
            endif  
          enddo  
          write(99,'(9999(1pE11.3))') (sum(i,j),j=1,N)
        enddo  
        write(99,*) "maximum error=",err
        print*,"matrix inversion error=",err
      endif  


      end
