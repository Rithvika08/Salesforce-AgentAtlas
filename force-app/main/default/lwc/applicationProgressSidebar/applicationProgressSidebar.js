import { LightningElement, api } from 'lwc';

export default class ApplicationProgressSidebar extends LightningElement {

    @api currentPage = 1;

    @api totalPages = 5;

    @api pageTitles = {};

    defaultPageTitles = {

        1: 'Personal Information',

        2: 'Contact Information',

        3: 'Educational Background',

        4: 'Program Selection & Academic Interests',

        5: 'Essays & Final Questions'

    };

    get steps() {

        return Array.from(

            {
                length: Number(this.totalPages) || 1
            },

            (_, index) => {

                const pageNumber =
                    index + 1;

                return {

                    id: pageNumber,
                    label:
                        this.pageTitles?.[pageNumber] ||
                        this.defaultPageTitles[pageNumber] ||
                        `Page ${pageNumber}`,
                    completed:
                        this.currentPage > pageNumber,
                    circleClass:
                        this.getClass(pageNumber)

                };

            }

        );

    }

    getClass(step) {

        if (step < this.currentPage) {

            return 'progress-circle completed';

        }

        if (step === this.currentPage) {

            return 'progress-circle current';

        }

        return 'progress-circle pending';

    }

}
