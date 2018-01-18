************************************************************************
      subroutine INIT_GRID
************************************************************************
      use NATURE,ONLY: bk,amu,km,bar
      use GRID,ONLY: Npoints,zz
      use READMODEL,ONLY: Nlayers,zlay,Tlay,play,rholay,glay,Difflay
      use STRUCT,ONLY: Diff,rho,nHtot,Temp,press,mu,mols,atms,elec
      use CHEMISTRY,ONLY: NMOLE
      use ELEMENTS,ONLY: NELEM
      use PARAMETERS,ONLY: Hp,pmin,pmax
      implicit none
      integer :: i,j
      real :: fac1,fac2,hmin,hmax

      allocate(zz(Npoints),Diff(Npoints),rho(Npoints),nHtot(Npoints),
     >         Temp(Npoints),press(Npoints),mu(Npoints),
     >         mols(NMOLE,Npoints),atms(NELEM,Npoints),elec(Npoints))

      hmin = 0.0
      hmax = 0.0
      do j=1,Nlayers
        !print*,j,zlay(j),play(j)/bar 
        if (play(j)>pmin*bar.and.hmax==0.0) hmax=zlay(j) 
        if (play(j)>pmax*bar.and.hmin==0.0) hmin=zlay(j) 
      enddo   
      !write(*,*) hmin,hmax
      do i=1,Npoints
        zz(i) = hmin+(hmax-hmin)*(REAL(i-1)/REAL(Npoints-1))**1.0
      enddo
  
      write(*,*)
      write(*,1000) "","z[km]","p[bar]","T[K]","mu[amu]","Diff[cm2/s]"
      j=Nlayers
      do i=1,Npoints
        do 
          if (zz(i)<zlay(j-1).or.j==2) exit
          j=j-1
        enddo  
        !--- check zlay(j)<=zz(i)<zlay(j-1) ---
        if (zlay(j)>zz(i).or.zz(i)>zlay(j-1)) then
          print*,"could not bracket z-gridpoint" 
          print*,i,j,zlay(j),zz(i),zlay(j-1)
          stop
        endif   
        fac2 = (zlay(j)-zz(i))/(zlay(j)-zlay(j-1))
        fac1 = 1.0-fac2
        !print*,i,j,zlay(j),zz(i),zlay(j-1),fac2
        Temp(i)  = Tlay(j)*fac1 + Tlay(j-1)*fac2
        press(i) = EXP(LOG(play(j))*fac1 + LOG(play(j-1))*fac2)
        rho(i)   = EXP(LOG(rholay(j))*fac1 + LOG(rholay(j-1))*fac2)
        nHtot(i) = rho(i)/(1.4*amu)
        Diff(i)  = EXP(LOG(Difflay(j))*fac1 + LOG(Difflay(j-1))*fac2)
        mu(i)    = rho(i)/press(i)*bk*Temp(i)
        write(*,1010) i,j,(zz(i)-zz(1))/km,press(i)/bar,Temp(i),
     >                mu(i)/amu,Diff(i)
      enddo
      zz(:) = zz(:)-zz(1)

 1000 format(A8,A11,A11,A11,A9,A12)
 1010 format(I4,I4,0pF11.3,1pE11.3,0pF11.2,0pF9.3,1pE12.3)
      end