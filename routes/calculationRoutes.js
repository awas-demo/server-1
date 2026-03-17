const express = require('express');
const CalculationController = require('../controllers/calculationController');

const router = express.Router();

router.post('/', CalculationController.saveCalculation);
router.get('/', CalculationController.getAllCalculations);
router.get('/:id', CalculationController.getCalculation);
router.delete('/:id', CalculationController.deleteCalculation);

module.exports = router;