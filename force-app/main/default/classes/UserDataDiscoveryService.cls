public with sharing class UserDataDiscoveryService {

    public class FormQuestion {

        @AuraEnabled
        public String questionId;

        @AuraEnabled
        public String questionText;

        @AuraEnabled
        public String questionType;

        @AuraEnabled
        public Integer pageNumber;

    }

    public class DataDiscoveryResult {

        @AuraEnabled
        public String questionId;

        @AuraEnabled
        public String recommendedValue;

        @AuraEnabled
        public Decimal bestMatchConfidence;

        @AuraEnabled
        public String reasoning;

        @AuraEnabled
        public List<String> sourceFields =
            new List<String>();

    }

    @AuraEnabled
    public static Map<String, DataDiscoveryResult>
    discoverDataForForm(

        Id userId,

        List<FormQuestion> questions

    ) {

        Map<String, DataDiscoveryResult>
            results =
                new Map<String, DataDiscoveryResult>();

        User usr = [

            SELECT
                Id,
                FirstName,
                LastName,
                Email,
                Phone,
                Street,
                City,
                State,
                PostalCode,
                Country,
                ContactId

            FROM User

            WHERE Id = :userId

            LIMIT 1

        ];

        Contact con = null;

        if (

            usr.ContactId != null

        ) {

            List<Contact> contacts = [

                SELECT
                    Id,
                    Birthdate,
                    Gender__c,
                    Citizenship_Status__c,
                    Languages__c,
                    GPA__c,
                    Applicant_Knowledge__c

                FROM Contact

                WHERE Id = :usr.ContactId

                LIMIT 1

            ];

            if (

                !contacts.isEmpty()

            ) {

                con = contacts[0];

            }

        }

        for (

            FormQuestion q
            : questions

        ) {

            DataDiscoveryResult res =
                new DataDiscoveryResult();

            res.questionId =
                q.questionId;

            String label = '';

            if (

                q.questionText != null

            ) {

                label =
                    q.questionText.toLowerCase().trim();

            }

            Boolean matched = false;

            /*
             * USER FIELDS
             */

            if (

                label.contains('first name')

            ) {

                res.recommendedValue =
                    usr.FirstName;

                matched = true;

            }

            else if (

                label.contains('last name')

            ) {

                res.recommendedValue =
                    usr.LastName;

                matched = true;

            }

            else if (

                label.contains('email')

            ) {

                res.recommendedValue =
                    usr.Email;

                matched = true;

            }

            else if (

                label.contains('phone') ||

                label.contains('mobile')

            ) {

                res.recommendedValue =
                    usr.Phone;

                matched = true;

            }

            else if (

                label.contains('street')

            ) {

                res.recommendedValue =
                    usr.Street;

                matched = true;

            }

            else if (

                label.contains('current address') &&

                label.contains('city')

            ) {

                res.recommendedValue =
                    usr.City;

                matched = true;

            }

            else if (

                label.contains('state/province') ||

                label.contains('province')

            ) {

                res.recommendedValue =
                    usr.State;

                matched = true;

            }

            else if (

                label.contains('postal') ||

                label.contains('zip')

            ) {

                res.recommendedValue =
                    usr.PostalCode;

                matched = true;

            }

            else if (

                label.equals(
                    'country'
                )

            ) {

                res.recommendedValue =
                    usr.Country;

                matched = true;

            }

            /*
             * CONTACT FIELDS
             */

            else if (

                con != null

            ) {

                if (

                    label.contains('date of birth')

                ) {

                    if (

                        con.Birthdate != null

                    ) {

                        res.recommendedValue =
                            String.valueOf(
                                con.Birthdate
                            );

                    }

                    matched = true;

                }

                else if (

                    label.contains('gender')

                ) {

                    res.recommendedValue =
                        con.Gender__c;

                    matched = true;

                }

                else if (

                    label.contains('citizenship')

                ) {

                    res.recommendedValue =
                        con.Citizenship_Status__c;

                    matched = true;

                }

                else if (

                    label.contains('primary language')

                ) {

                    res.recommendedValue =
                        con.Languages__c;

                    matched = true;

                }

                else if (

                    label.contains('gpa')

                ) {

                    if (

                        con.GPA__c != null

                    ) {

                        res.recommendedValue =
                            String.valueOf(
                                con.GPA__c
                            );

                    }

                    matched = true;

                }

            }

            /*
             * KNOWLEDGE FIELD
             */

            if (

                !matched &&

                con != null &&

                !String.isBlank(
                    con.Applicant_Knowledge__c
                )

            ) {

                String knowledge =
                    con.Applicant_Knowledge__c;

                String lower =
                    knowledge.toLowerCase();

                /*
                 * PROGRAM APPLYING FOR
                 */

                if (

                    label.contains(
                        'program applying'
                    )

                ) {

                    if (

                        lower.contains('ms cs')

                    ) {

                        res.recommendedValue =
                            'MS CS';

                    }

                    else if (

                        lower.contains('mba')

                    ) {

                        res.recommendedValue =
                            'MBA';

                    }

                    else if (

                        lower.contains('mph')

                    ) {

                        res.recommendedValue =
                            'MPH';

                    }

                    else if (

                        lower.contains('med')

                    ) {

                        res.recommendedValue =
                            'MEd';

                    }

                    else if (

                        lower.contains('meng')

                    ) {

                        res.recommendedValue =
                            'MEng';

                    }

                    else if (

                        lower.contains(
                            'phd data science'
                        )

                    ) {

                        res.recommendedValue =
                            'PhD Data Science';

                    }

                    else {

                        res.recommendedValue =
                            'Other';

                    }

                    matched = true;

                }

                /*
                 * ENROLLMENT STATUS
                 */

                else if (

                    label.contains(
                        'enrollment'
                    )

                ) {

                    if (

                        lower.contains(
                            'full time'
                        ) ||

                        lower.contains(
                            'full-time'
                        )

                    ) {

                        res.recommendedValue =
                            'Full-time';

                    }

                    else if (

                        lower.contains(
                            'part time'
                        ) ||

                        lower.contains(
                            'part-time'
                        )

                    ) {

                        res.recommendedValue =
                            'Part-time';

                    }

                    matched = true;

                }

                /*
                 * SPECIALIZATION
                 */

                else if (

                    label.contains(
                        'specialization'
                    ) ||

                    label.contains(
                        'concentration'
                    )

                ) {

                    if (

                        lower.contains(
                            'artificial intelligence'
                        ) ||

                        lower.contains(
                            ' ai '
                        )

                    ) {

                        res.recommendedValue =
                            'AI';

                    }

                    else if (

                        lower.contains(
                            'cybersecurity'
                        )

                    ) {

                        res.recommendedValue =
                            'Cybersecurity';

                    }

                    else if (

                        lower.contains(
                            'data science'
                        )

                    ) {

                        res.recommendedValue =
                            'Data Science';

                    }

                    matched = true;

                }

                /*
                 * FIELD OF STUDY
                 */

                else if (

                    label.contains(
                        'field of study'
                    )

                ) {

                    Pattern p =
                        Pattern.compile(
                            '(?i)degree in\\s+([A-Za-z\\s]+?)\\s+from'
                        );

                    Matcher m =
                        p.matcher(knowledge);

                    if (

                        m.find()

                    ) {

                        res.recommendedValue =
                            m.group(1).trim();

                    }

                    matched = true;

                }

                /*
                 * HIGHEST LEVEL OF EDUCATION
                 */

                else if (

                    label.contains(
                        'highest level of education'
                    )

                ) {

                    if (

                        lower.contains(
                            'bachelor'
                        )

                    ) {

                        res.recommendedValue =
                            'Bachelor\'s';

                    }

                    else if (

                        lower.contains(
                            'master'
                        )

                    ) {

                        res.recommendedValue =
                            'Master\'s';

                    }

                    else if (

                        lower.contains(
                            'doctor'
                        ) ||

                        lower.contains(
                            'phd'
                        )

                    ) {

                        res.recommendedValue =
                            'Doctoral';

                    }

                    else if (

                        lower.contains(
                            'associate'
                        )

                    ) {

                        res.recommendedValue =
                            'Associate';

                    }

                    else {

                        res.recommendedValue =
                            'High School';

                    }

                    matched = true;

                }

                /*
                 * GRE VERBAL
                 */

                else if (

                    label.contains(
                        'gre verbal'
                    )

                ) {

                    Pattern p =
                        Pattern.compile(
                            '(?i)gre verbal score is\\s*(\\d{2,3})'
                        );

                    Matcher m =
                        p.matcher(knowledge);

                    if (

                        m.find()

                    ) {

                        res.recommendedValue =
                            m.group(1);

                    }

                    matched = true;

                }

                /*
                 * GRE QUANT
                 */

                else if (

                    label.contains(
                        'gre quant'
                    )

                ) {

                    Pattern p =
                        Pattern.compile(
                            '(?i)gre quant score is\\s*(\\d{2,3})'
                        );

                    Matcher m =
                        p.matcher(knowledge);

                    if (

                        m.find()

                    ) {

                        res.recommendedValue =
                            m.group(1);

                    }

                    matched = true;

                }

                /*
                 * CITY OF INSTITUTION
                 */

                else if (

                    label.contains(
                        'city of institution'
                    )

                ) {

                    if (

                        lower.contains(
                            'hyderabad'
                        )

                    ) {

                        res.recommendedValue =
                            'Hyderabad';

                    }

                    else if (

                        lower.contains(
                            'bangalore'
                        )

                    ) {

                        res.recommendedValue =
                            'Bangalore';

                    }

                    else if (

                        lower.contains(
                            'chennai'
                        )

                    ) {

                        res.recommendedValue =
                            'Chennai';

                    }

                    matched = true;

                }

                /*
                 * COUNTRY OF INSTITUTION
                 */

                else if (

                    label.contains(
                        'country of institution'
                    )

                ) {

                    if (

                        lower.contains(
                            'india'
                        )

                    ) {

                        res.recommendedValue =
                            'India';

                    }

                    else if (

                        lower.contains(
                            'canada'
                        )

                    ) {

                        res.recommendedValue =
                            'Canada';

                    }

                    else if (

                        lower.contains(
                            'united kingdom'
                        )

                    ) {

                        res.recommendedValue =
                            'United Kingdom';

                    }

                    else if (

                        lower.contains(
                            'china'
                        )

                    ) {

                        res.recommendedValue =
                            'China';

                    }

                    else if (

                        lower.contains(
                            'united states'
                        ) ||

                        lower.contains(
                            'usa'
                        )

                    ) {

                        res.recommendedValue =
                            'United States';

                    }

                    else {

                        res.recommendedValue =
                            'Other';

                    }

                    matched = true;

                }

                /*
                 * COMPETITIVE EXAMS
                 */

                else if (

                    label.contains(
                        'competitive exams'
                    )

                ) {

                    Pattern p =
                        Pattern.compile(
                            '(?i)have taken\\s+([A-Za-z\\s,]+?)\\s+examinations'
                        );

                    Matcher m =
                        p.matcher(knowledge);

                    if (

                        m.find()

                    ) {

                        String exams =
                            m.group(1).trim();

                        exams =
                            exams.replace(
                                ' and ',
                                ', '
                            );

                        res.recommendedValue =
                            exams;

                    }

                    matched = true;

                }

            }

            if (

                !String.isBlank(
                    res.recommendedValue
                )

            ) {

                res.bestMatchConfidence =
                    0.95;

                res.reasoning =
                    'Dynamic Salesforce field mapping';

                results.put(
                    q.questionId,
                    res
                );

            }

        }

        return results;

    }

}