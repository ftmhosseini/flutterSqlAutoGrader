describe('Teacher Datasets Page', () => {
  beforeEach(() => {
    cy.loginAsTeacher();
    cy.visit('/dashboard/datasets');
  });

  it('loads dataset manager', () => {
    cy.url().should('include', '/dashboard/datasets');
    cy.contains('Dataset Manager').should('be.visible');
  });

  it('shows dataset dropdown and create input', () => {
    cy.get('select').should('exist');
    cy.get('input[placeholder="New dataset name"]').should('be.visible');
  });

  it('shows Create Dataset button', () => {
    cy.contains('button', 'Create Dataset').should('be.visible');
  });

  it('shows hint popup on click', () => {
    cy.contains('?').click();
    cy.contains('Database Manager Guide').should('be.visible');
  });
});
