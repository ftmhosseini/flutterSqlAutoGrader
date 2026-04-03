describe('Teacher Cohorts Page', () => {
  beforeEach(() => {
    cy.loginAsTeacher();
    cy.visit('/dashboard/cohorts');
  });

  it('loads cohorts page', () => {
    cy.url().should('include', '/dashboard/cohorts');
    cy.contains('Cohort').should('be.visible');
  });

  it('shows cohort creation form', () => {
    cy.get('input').should('exist');
  });
});
