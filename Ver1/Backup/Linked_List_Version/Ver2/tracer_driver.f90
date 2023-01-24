PROGRAM tracer_test_run
    USE constants_mod
	USE tracertype_mod
    USE data_mod
	USE tracersolver_mod
	IMPLICIT NONE


	! define mass flux tracer object
    TYPE(MASSFLUXTRACER) :: solver


    REAL :: dt1, dx1, dy1

	
	IF(ndims .EQ. 1) THEN
		ALLOCATE(tr1d(1:N))
		ALLOCATE(cellHead1d(0:nx+1))
		ALLOCATE(rho(1:nx), flux(0:nx))
		ALLOCATE(N_cell(0:nx+1))
  
    ELSE IF(ndims .EQ. 2) THEN
		ALLOCATE(tr2d(1:N))
		ALLOCATE(cellHead2d(0:nx+1,0:ny+1))
		ALLOCATE(rho2d(1:nx,1:ny), flux2d(0:nx,0:ny,2))
		ALLOCATE(N_cell2d(0:nx+1,0:ny+1))
    END IF


    N_cell = 0

	! set up solver object
    solver = MASSFLUXTRACER(ndims,nx,ny,nz,N)
    CALL solver%initialize_workpool()


    ! initialize tracers
    CALL initialize_tracer_distribution(tr1d, cellHead1d, N_cell)
   
    ! advance by one advection step using sample rho and flux arrays
    dt1 = 0.1/2.
    dx1 = 1./real(nx)
    dy1 = 1./real(ny) 
    rho = 1.
    flux = (/ -1., -1., -1., 1., 1., 1. /)
    
    
    CALL solver%solve(dt1, dx1, dy1)
	

    CALL solver%destroy_workpool()



	IF(ndims .EQ. 1) THEN
		DEALLOCATE(tr1d,cellHead1d,rho,flux,N_cell)
  
    ELSE IF(ndims .EQ. 2) THEN
		DEALLOCATE(tr2d,cellHead2d,rho2d,flux2d,N_cell2d)

    END IF


    PRINT*,'DONE!'




	CONTAINS

		! This subroutine assigns a cell to each tracer 
        ! (according to a given distribution)
        ! For now, tracers will be randomly distributed
        ! across the cells.
		SUBROUTINE initialize_tracer_distribution(tr, cellHead1d, N_cell)

			TYPE(tracer_ptr_1d), INTENT(INOUT) :: tr(:),cellHead1d(:)
            INTEGER, INTENT(INOUT) :: N_cell(:)

			TYPE(tracer_1d), POINTER :: current
     		INTEGER :: i, cellnum
            REAL :: p 
        

            ! loop over tracers, assign them to cells
            DO i = 1, N

                ! allocate memory for tracer pointer
                ALLOCATE(tr(i)%p) 

            	! draw a random integer between 1 and nx
                CALL RANDOM_NUMBER(p)
                cellnum= 1+FLOOR(p*nx)

				! assign id and cell number to tracer 
                tr(i)%p%id = i
                tr(i)%p%x = cellnum
                N_cell(cellnum+1) = N_cell(cellnum+1)+1

                ! if cell is empty, designate this tracer as head
                IF(.NOT. ASSOCIATED(cellHead1d(cellnum+1)%p)) THEN
                   cellHead1d(cellnum+1)%p => tr(i)%p

				! otherwise add current tracer to the cell's linked list                
				ELSE
	              	current => cellHead1d(cellnum+1)%p

                     
                    DO WHILE(ASSOCIATED(current%next))
                        ! traverse through list until last tracer is reached
						current => current%next			
                    END DO
                    current%next => tr(i)%p
				END IF				     

			END DO


        	PRINT*, 'Tracer initialization completed.'

		END SUBROUTINE initialize_tracer_distribution


END PROGRAM tracer_test_run

