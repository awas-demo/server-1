let Calculation;

try {
    Calculation = require('../models/calculation');
} catch (err) {
    console.log('Calculation model not available');
}

class CalculationController {
    static async saveCalculation(req, res) {
        try {
            if (!Calculation) {
                return res.status(503).json({ error: 'Calculation service not available' });
            }

            const { user_id, expression, result } = req.body;
            
            const calculation = await Calculation.create({
                user_id,
                expression,
                result
            });
            
            res.status(201).json(calculation);
        } catch (error) {
            res.status(500).json({ error: error.message });
        }
    }

    static async getAllCalculations(req, res) {
        try {
            if (!Calculation) {
                return res.status(503).json({ error: 'Calculation service not available' });
            }

            const calculations = await Calculation.findAll();
            res.json(calculations);
        } catch (error) {
            res.status(500).json({ error: error.message });
        }
    }

    static async getCalculation(req, res) {
        try {
            if (!Calculation) {
                return res.status(503).json({ error: 'Calculation service not available' });
            }

            const { id } = req.params;
            const calculation = await Calculation.findByPk(id);
            
            if (!calculation) {
                return res.status(404).json({ error: 'Calculation not found' });
            }
            
            res.json(calculation);
        } catch (error) {
            res.status(500).json({ error: error.message });
        }
    }

    static async deleteCalculation(req, res) {
        try {
            if (!Calculation) {
                return res.status(503).json({ error: 'Calculation service not available' });
            }

            const { id } = req.params;
            const calculation = await Calculation.findByPk(id);
            
            if (!calculation) {
                return res.status(404).json({ error: 'Calculation not found' });
            }
            
            await calculation.destroy();
            res.json({ message: 'Calculation deleted successfully' });
        } catch (error) {
            res.status(500).json({ error: error.message });
        }
    }
}

module.exports = CalculationController;