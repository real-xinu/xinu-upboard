/* ttyinit.c - ttyinit */

#include <xinu.h>

struct	ttycblk	ttytab[Ntty];

/*------------------------------------------------------------------------
 *  ttyinit  -  Initialize buffers and modes for a tty line
 *------------------------------------------------------------------------
 */
devcall	ttyinit(
	  struct dentry	*devptr		/* Entry in device switch table	*/
	)
{
	struct	ttycblk	*typtr;		/* Pointer to ttytab entry	*/
	struct	uart_csreg *uptr;	/* Address of UART's CSRs	*/
	uint32	pcidev;			/* Encoded PCI device		*/

	typtr = &ttytab[ devptr->dvminor ];

	/* Initialize values in the tty control block */

	typtr->tyihead = typtr->tyitail = 	/* Set up input queue	*/
		&typtr->tyibuff[0];		/*    as empty		*/
	typtr->tyisem = semcreate(0);		/* Input semaphore	*/
	typtr->tyohead = typtr->tyotail = 	/* Set up output queue	*/
		&typtr->tyobuff[0];		/*    as empty		*/
	typtr->tyosem = semcreate(TY_OBUFLEN);	/* Output semaphore	*/
	typtr->tyehead = typtr->tyetail = 	/* Set up echo queue	*/
		&typtr->tyebuff[0];		/*    as empty		*/
	typtr->tyimode = TY_IMCOOKED;		/* Start in cooked mode	*/
	typtr->tyiecho = TRUE;			/* Echo console input	*/
	typtr->tyieback = TRUE;			/* Honor erasing bksp	*/
	typtr->tyevis = TRUE;			/* Visual control chars	*/
	typtr->tyecrlf = TRUE;			/* Echo CRLF for NEWLINE*/
	typtr->tyicrlf = TRUE;			/* Map CR to NEWLINE	*/
	typtr->tyierase = TRUE;			/* Do erasing backspace	*/
	typtr->tyierasec = TY_BACKSP;		/* Primary erase char	*/
	typtr->tyierasec2= TY_BACKSP2;		/* Alternate erase char	*/
	typtr->tyeof = TRUE;			/* Honor eof on input	*/
	typtr->tyeofch = TY_EOFCH;		/* End-of-file character*/
	typtr->tyikill = TRUE;			/* Allow line kill	*/
	typtr->tyikillc = TY_KILLCH;		/* Set line kill to ^U	*/
	typtr->tyicursor = 0;			/* Start of input line	*/
	typtr->tyoflow = TRUE;			/* Handle flow control	*/
	typtr->tyoheld = FALSE;			/* Output not held	*/
	typtr->tyostop = TY_STOPCH;		/* Stop char is ^S	*/
	typtr->tyostart = TY_STRTCH;		/* Start char is ^Q	*/
	typtr->tyocrlf = TRUE;			/* Send CRLF for NEWLINE*/
	typtr->tyifullc = TY_FULLCH;		/* Send ^G when buffer	*/
						/*   is full		*/

	/* Get the encoded PCI for the UART device */

	// pcidev = find_pci_device(INTEL_QUARK_UART_PCI_DID,
	// 			 INTEL_QUARK_UART_PCI_VID,
	// 			 1);

	/* Initialize the UART */

	uptr = (struct uart_csreg *)devptr->dvcsr;

	// /* Set baud rate */
	// uptr->lcr = UART_LCR_DLAB;
	// uptr->dlm = 0x00;
	// uptr->dll = 0x18;

	// uptr->lcr = UART_LCR_8N1;	/* 8 bit char, No Parity, 1 Stop*/
	// uptr->fcr = 0x00;		/* Disable FIFO for now		*/

	// /* Register the interrupt handler for the tty device */

	// pci_set_ivec( pcidev, devptr->dvirq, devptr->dvintr,
	// 						(int32)devptr );

	// /* Enable interrupts on the device: reset the transmit and	*/
	// /*   receive FIFOS, and set the interrupt trigger level		*/

	// uptr->fcr = UART_FCR_EFIFO | UART_FCR_RRESET |
	// 		UART_FCR_TRESET | UART_FCR_TRIG2;

	// /* Start the device */

	// ttykickout(uptr);

	outb((int)&uptr->lcr, UART_LCR_8N1);	/* 8 bit char, No Parity, 1 Stop*/
	outb((int)&uptr->fcr, 0x00);		/* Disable FIFO for now		*/
	/* OUT2 value is used to control the onboard interrupt tri-state*/
	/* buffer. It should be set high to generate interrupts		*/
	outb((int)&uptr->mcr, UART_MCR_DTR | 
			      UART_MCR_RTS | 
			      UART_MCR_OUT2);	/* Turn on user-defined OUT2	*/

	/* Register the interrupt dispatcher for the tty device */

	set_evec( devptr->dvirq, (uint32)devptr->dvintr );

	/* Enable interrupts on the device */

	/* Enable UART FIFOs, clear and set interrupt trigger level	*/
	outb((int)&uptr->fcr, UART_FCR_EFIFO | UART_FCR_RRESET |
			      UART_FCR_TRESET | UART_FCR_TRIG2);

	ttyKickOut(typtr, uptr);
	(void)inb((int)&uptr->iir);
	(void)inb((int)&uptr->lsr);
	(void)inb((int)&uptr->msr);
	(void)inb((int)&uptr->buffer);

	return OK;
}
