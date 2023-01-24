PROGRAM tracer_test_run

USE MPI
USE constants_mod
USE tracertype_mod
USE data_mod
USE tracerInit_mod
USE tracersolver_mod
USE domain_mod

IMPLICIT NONE


! define solver object
TYPE(MASSFLUXTRACER) :: solver


REAL :: dt1, dx1, dy1, dz1
INTEGER :: i, ix, iy
INTEGER ::c_i,c_f
REAL*8 :: t1,t2,t_tot




!##########################################################################################

! Initialize MPI
CALL MPI_INIT(ierr)

! Get number of processes
CALL MPI_COMM_SIZE(MPI_COMM_WORLD, numprocs(1), ierr)

! set up domain decomposition
CALL setup_domain()

! get rank
CALL MPI_COMM_RANK(comm2d, myrank, ierr)

! get rank co-ordinates
CALL MPI_CART_COORDS(comm2d, myrank, ndims, mycoord, ierr)

! compute domain boundary indices
CALL compute_bound()

!allocate memory for MPI buffers
buffer_size = 1+nvars*max_mpi_buffer_particles
ALLOCATE(MPI_buffer_in(1:buffer_size),MPI_buffer_out(1:buffer_size))


PRINT*,''
PRINT*,'My rank, coordinate, xlow, xhi, ylow, yhi =',myrank, mycoord, xlow, xhi, ylow, yhi
PRINT*,''
!##########################################################################################



! Initialize the system_clock
!CALL system_clock(count_rate=cr)
!CALL system_clock(count_max=cm)
!rate = REAL(cr)
!WRITE(*,*) "system_clock rate = ",rate

ALLOCATE(tr(1:N))

IF(ndims .EQ. 1) THEN
    OPEN(UNIT=1, FILE='output1d.txt')	
   
    ALLOCATE(cellHead_1d(xlow:xhi))
    ALLOCATE(rho_1d(xlow:xhi), flux_1d(xlow:xhi-1))
    ALLOCATE(N_cell_1d(xlow:xhi))
  
    rho_1d = 0.0
    flux_1d = 0.0
    N_cell_1d = 0
 
ELSE IF(ndims .EQ. 2) THEN
    OPEN(UNIT=1, FILE='output1d.txt')	
   
    ALLOCATE(cellHead_2d(xlow:xhi,ylow:yhi))
    ALLOCATE(rho_2d(xlow:xhi,ylow:yhi), flux_2d(xlow:xhi-1,ylow:yhi-1,2))
    ALLOCATE(N_cell_2d(xlow:xhi,ylow:yhi))
  
    rho_2d = 0.0
    flux_2d = 0.0
    N_cell_2d = 0
 
ELSE IF(ndims .EQ. 3) THEN
    OPEN(UNIT=1, FILE='output1d.txt')	
   
    ALLOCATE(cellHead_3d(1-nb:nx+nb,1-nb:ny+nb,1-nb:nz+nb))
    ALLOCATE(rho_3d(1-nb:nx+nb,1-nb:ny+nb,1-nb:nz+nb), flux_3d(1-nb:nx,1-nb:ny,1-nb:nz,3))
    ALLOCATE(N_cell_3d(1-nb:nx+nb,1-nb:ny+nb,1-nb:nz+nb))
  
    rho_3d = 0.0
    flux_3d = 0.0
    N_cell_3d = 0

ELSE
    PRINT*,'NEED TO HAVE 1 <= NDIMS <= 3'
	STOP

END IF  
  
dt1 = 0.1/5.0
dx1 = 1./real(nx)
dy1 = 1./real(ny)
dz1 = 1./real(nz)

IF(ndims .EQ. 1) THEN
	rho_1d(:) = 1.
	
	DO ix = xlow, xhi-1 
	   	flux_1d(ix) = 0.2501*dx1/dt1
	END DO
		
END IF

IF(ndims .EQ. 2) THEN
	rho_2d(:,:) = 1.
	
	DO ix = xlow, xhi-1
		DO iy = ylow, yhi-1 
		    !IF(ix < nb+nx/2) THEN
			!	flux_2d(ix,iy,1) = -0.2501*dx1*dy1/dt1
			!ELSE
			!	flux_2d(ix,iy,1) = 0.2501*dx1*dy1/dt1
			!END IF
			flux_2d(ix,iy,1) = 0.2501*dx1*dy1/dt1
			flux_2d(ix,iy,2) = 0.d0!0.2501*dx1*dy1/dt1
		END DO
	END DO
END IF


!set up solver object
solver = MASSFLUXTRACER(ndims,nb,N,dx1,dy1,dz1)
CALL solver%initialize_workpool()

! initialize tracers
IF(ndims .EQ. 1) CALL initialize_tracer_distribution_1d(N_cell_1d, cellHead_1d)

IF(ndims .EQ. 2) CALL initialize_tracer_distribution_2d(N_cell_2d, cellHead_2d)



!        CALL output1d(N_cell1d)

t1 = MPI_Wtime()
! Simulation loop    
DO i= 1, nt
    PRINT*,' '
    PRINT*,'TIME STEP, % complete = ',i, (i*100./(nt*1.))
    PRINT*,' '

    CALL solver%solve(dt1)
  
    IF(ndims .EQ. 1) THEN
	!	PRINT*,''
	!	DO ix = 1-nb, nx+nb 
	!		WRITE(*,FMT='(i4)', ADVANCE = 'NO'), N_cell_1d(ix)
	!	END DO
	!	PRINT*,''
	!	PRINT*,''
	    CALL output1d(N_cell_1d)
	END IF  
  
    IF(ndims .EQ. 2) THEN
		PRINT*,''
		DO iy = yhi , ylow, -1
			DO ix = xlow, xhi 
				WRITE(*,FMT='(i4)', ADVANCE = 'NO'), N_cell_2d(ix,iy)
			END DO
			PRINT*,''
		END DO
		PRINT*,''
	    CALL output2d(N_cell_2d,i)
	END IF
	
	
END DO
t2 = MPI_Wtime()
 
t_tot = t2-t1
 



PRINT*,'Total simulation time (sec) =',t_tot
PRINT*,'Advect Time (sec) = ',advecttime
PRINT*,'Rand num generation Time (sec) = ',randtime
PRINT*,'Rand time fraction =', randtime/t_tot
PRINT*,'Advect time fraction =', advecttime/t_tot


CALL solver%destroy_workpool()


DO i= 1,N
    DEALLOCATE(tr(i)%p)
END DO

IF(ndims .EQ. 1) DEALLOCATE(cellHead_1d, rho_1d, flux_1d, N_cell_1d)
IF(ndims .EQ. 2) DEALLOCATE(cellHead_2d, rho_2d, flux_2d, N_cell_2d)
IF(ndims .EQ. 3) DEALLOCATE(cellHead_3d, rho_3d, flux_3d, N_cell_3d)



CLOSE(UNIT=1)



!##########################################################################################
!Terminate MPI
CALL MPI_FINALIZE(ierr)
!##########################################################################################



PRINT*,'RANK#',myrank,' DONE!'

CONTAINS



SUBROUTINE output1d(N_cell)

    INTEGER, INTENT(INOUT) :: N_cell(:)
    INTEGER :: i
    REAL :: x

    DO i=1,nx
        x=i*dx1
        WRITE(1,*) x,N_Cell(i)
    END DO

END SUBROUTINE output1d


SUBROUTINE output2d(N_cell,ts)

	INTEGER, INTENT(IN) :: N_cell(1-nb:nx+nb,1-nb:ny+nb), ts
    INTEGER :: i,j
	REAL :: x,y
    CHARACTER(len=40)::filename
    CHARACTER(len=6)::uniti


	IF(ts < 10) THEN
		WRITE(uniti,'(I1.1)') ts
	ELSE IF(ts>=10 .and. ts<100) THEN
		WRITE(uniti,'(I2.2)') ts
	ELSE IF(ts>=100 .and. ts<1000) THEN
		WRITE(uniti,'(I3.3)') ts
	ELSE IF(ts>=1000 .and. ts<10000) THEN
		WRITE(uniti,'(I4.3)') ts
	ELSE IF(ts>=10000 .and. ts<100000) THEN
		WRITE(uniti,'(I5.3)') ts
	END IF
  
filename=trim('Output/t=')//trim(uniti)//trim('.txt')
!print*,'filename=',filename

OPEN(unit=12,file=filename)

DO j = 1-nb, ny+nb
    y = (j-1) * dy1
    DO i = 1-nb , nx+nb
       x = (i-1) * dx1
       WRITE(12,*) x,y,REAL(N_cell(i,j))
  END DO
END DO

CLOSE(12)

END SUBROUTINE output2d


		
END PROGRAM tracer_test_run

